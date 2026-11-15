import Foundation
import AppKit
import Combine

private struct SupabaseCheckInDTO: Codable {
    let id: String
    let timestamp: String
    let body_energy: Int
    let mental_resource: Int
    let focus: Int
    let tags: [String]
    let note: String
    let screen_time_seconds: Int
    let metric_scores: [String: Int]
}

@MainActor
final class CloudSyncService: ObservableObject {
    static let shared = CloudSyncService()

    private let baseURL = "https://ztjxxmyqrbdclzexluxz.supabase.co/rest/v1"
    private let apiKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp0anh4bXlxcmJkY2x6ZXhsdXh6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ3NTgzNTgsImV4cCI6MjExMDMzNDM1OH0.0rLiWUrtUCR5zE2tIDswJBVfQ_pA3c2S2xqmubYavcg"

    @Published var isSyncing: Bool = false
    @Published var lastSyncTime: Date? = nil
    @Published var isConnected: Bool = true
    @Published var statusMessage: String = "Синхронизировано"

    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private let fallbackFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private var syncTimer: Timer?

    private init() {
        Task {
            await syncAll()
        }
        setupAutoSync()
    }

    private func setupAutoSync() {
        // Periodic background auto-sync every 15 seconds
        syncTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.syncAll()
            }
        }

        // Auto sync when app becomes active
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.syncAll()
            }
        }

        // Auto sync when Mac wakes from sleep
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.syncAll()
            }
        }
    }

    // MARK: - Headers
    private func makeRequest(url: URL, method: String) -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(apiKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 10
        return req
    }

    // MARK: - Push Single CheckIn
    func pushCheckIn(_ record: CheckInRecord) {
        guard isConnected else { return }

        Task {
            let dto = SupabaseCheckInDTO(
                id: record.id.uuidString.lowercased(),
                timestamp: fallbackFormatter.string(from: record.timestamp),
                body_energy: record.bodyEnergy,
                mental_resource: record.mentalResource,
                focus: record.focus,
                tags: record.tags,
                note: record.note,
                screen_time_seconds: record.screenTimeSeconds,
                metric_scores: record.metricScores
            )

            guard let url = URL(string: "\(baseURL)/check_ins") else { return }
            var req = makeRequest(url: url, method: "POST")
            req.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

            do {
                req.httpBody = try JSONEncoder().encode([dto])
                let (_, response) = try await URLSession.shared.data(for: req)
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    self.lastSyncTime = Date()
                    self.statusMessage = "Синхронизировано"
                }
            } catch {
                // Network error - offline mode continues uninterrupted
            }
        }
    }

    // MARK: - Delete Single CheckIn
    func deleteCheckIn(id: UUID) {
        guard isConnected else { return }

        Task {
            guard let url = URL(string: "\(baseURL)/check_ins?id=eq.\(id.uuidString.lowercased())") else { return }
            let req = makeRequest(url: url, method: "DELETE")
            _ = try? await URLSession.shared.data(for: req)
        }
    }

    // MARK: - Full Bi-directional Sync
    func syncAll() async {
        guard !isSyncing else { return }
        isSyncing = true
        statusMessage = "Синхронизация..."

        guard let url = URL(string: "\(baseURL)/check_ins?select=*") else {
            isSyncing = false
            return
        }

        let req = makeRequest(url: url, method: "GET")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                isSyncing = false
                statusMessage = "Ошибка соединения"
                return
            }

            let remoteDTOs = try JSONDecoder().decode([SupabaseCheckInDTO].self, from: data)

            // 1. Merge Remote into Local
            let localRecords = DatabaseManager.shared.fetchAllCheckIns()
            let localMap = Dictionary(uniqueKeysWithValues: localRecords.map { ($0.id.uuidString.lowercased(), $0) })

            var newDownloaded = 0
            for dto in remoteDTOs {
                guard let uuid = UUID(uuidString: dto.id) else { continue }
                if localMap[dto.id.lowercased()] == nil {
                    // Parse date
                    let date = isoFormatter.date(from: dto.timestamp) ?? fallbackFormatter.date(from: dto.timestamp) ?? Date()

                    let newRecord = CheckInRecord(
                        id: uuid,
                        timestamp: date,
                        metricScores: dto.metric_scores,
                        tags: dto.tags,
                        note: dto.note,
                        screenTimeSeconds: dto.screen_time_seconds
                    )
                    DatabaseManager.shared.saveCheckInLocally(newRecord)
                    newDownloaded += 1
                }
            }

            // 2. Upload any local records not on remote
            let remoteSet = Set(remoteDTOs.map { $0.id.lowercased() })
            var toUpload: [SupabaseCheckInDTO] = []

            for record in localRecords {
                if !remoteSet.contains(record.id.uuidString.lowercased()) {
                    let dto = SupabaseCheckInDTO(
                        id: record.id.uuidString.lowercased(),
                        timestamp: fallbackFormatter.string(from: record.timestamp),
                        body_energy: record.bodyEnergy,
                        mental_resource: record.mentalResource,
                        focus: record.focus,
                        tags: record.tags,
                        note: record.note,
                        screen_time_seconds: record.screenTimeSeconds,
                        metric_scores: record.metricScores
                    )
                    toUpload.append(dto)
                }
            }

            if !toUpload.isEmpty, let postURL = URL(string: "\(baseURL)/check_ins") {
                var postReq = makeRequest(url: postURL, method: "POST")
                postReq.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
                postReq.httpBody = try JSONEncoder().encode(toUpload)
                _ = try? await URLSession.shared.data(for: postReq)
            }

            lastSyncTime = Date()
            statusMessage = "Синхронизировано"
            isSyncing = false

            if newDownloaded > 0 {
                NotificationCenter.default.post(name: .databaseDidChange, object: nil)
            }
        } catch {
            isSyncing = false
            statusMessage = "Офлайн-режим"
        }
    }
}

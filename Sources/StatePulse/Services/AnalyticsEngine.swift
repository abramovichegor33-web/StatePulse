import Foundation
import SwiftUI

enum AnalyticsPeriod: Int, CaseIterable, Identifiable {
    case days7 = 7
    case days30 = 30
    case days90 = 90
    case year = 365

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .days7: return "7 дней"
        case .days30: return "30 дней"
        case .days90: return "90 дней"
        case .year: return "Весь год"
        }
    }
}

struct SingleMetricStat: Identifiable {
    var id: String { metricId }
    let metricId: String
    let name: String
    let icon: String
    let color: Color
    let average: Double
    let delta: Double
}

struct MetricSummary {
    let metricStats: [SingleMetricStat]
    let compositeAvg: Double
    let compositeDelta: Double
    let totalEntries: Int
    let currentStreakDays: Int

    var bodyAvg: Double { metricStats.first(where: { $0.metricId == "body" })?.average ?? compositeAvg }
    var bodyDelta: Double { metricStats.first(where: { $0.metricId == "body" })?.delta ?? compositeDelta }
    var mindAvg: Double { metricStats.first(where: { $0.metricId == "mind" })?.average ?? compositeAvg }
    var mindDelta: Double { metricStats.first(where: { $0.metricId == "mind" })?.delta ?? compositeDelta }
    var focusAvg: Double { metricStats.first(where: { $0.metricId == "focus" })?.average ?? compositeAvg }
    var focusDelta: Double { metricStats.first(where: { $0.metricId == "focus" })?.delta ?? compositeDelta }
}

struct DailyChartPoint: Identifiable {
    var id: String { dateString }
    let date: Date
    let dateString: String
    var scoresByMetric: [String: Double]
    let composite: Double
    var movingAverage: Double?

    var body: Double { scoresByMetric["body"] ?? composite }
    var mind: Double { scoresByMetric["mind"] ?? composite }
    var focus: Double { scoresByMetric["focus"] ?? composite }

    func score(for metricId: String) -> Double {
        scoresByMetric[metricId] ?? 0
    }
}

struct IntradayPhaseStat: Identifiable {
    var id: String { phase.rawValue }
    let phase: TimeOfDayPhase
    let averageScore: Double
    let checkInCount: Int
    let metricAverages: [String: Double]
}

struct HourlyCurvePoint: Identifiable {
    var id: Int { hour }
    let hour: Int
    let hourLabel: String
    let composite: Double
    let metricScores: [String: Double]
    let sampleCount: Int
}

struct HeatmapDay: Identifiable {
    var id: String { dateString }
    let date: Date
    let dateString: String
    let level: Int             // 0 ... 4
    let score: Double
    let count: Int
    let tags: [String]
    let notes: [String]
    let dayOfWeek: Int         // 1 = Monday, 7 = Sunday
    let records: [CheckInRecord]
}

struct HeatmapWeek: Identifiable {
    var id: Int { weekIndex }
    let weekIndex: Int
    let days: [HeatmapDay]
}

final class AnalyticsEngine {
    static let shared = AnalyticsEngine()

    private init() {}

    // MARK: - Metric Summary
    func calculateSummary(records: [CheckInRecord], period: AnalyticsPeriod, metrics: [MetricDefinition]) -> MetricSummary {
        let now = Date()
        let calendar = Calendar.current
        let days = period.rawValue

        guard let periodStart = calendar.date(byAdding: .day, value: -days, to: now),
              let prevPeriodStart = calendar.date(byAdding: .day, value: -(days * 2), to: now) else {
            return emptySummary(metrics: metrics)
        }

        let currentRecords = records.filter { $0.timestamp >= periodStart && $0.timestamp <= now }
        let prevRecords = records.filter { $0.timestamp >= prevPeriodStart && $0.timestamp < periodStart }

        var stats: [SingleMetricStat] = []
        for metric in metrics {
            let curAvg = average(currentRecords.map { Double($0.score(for: metric.id)) })
            let prevAvg = average(prevRecords.map { Double($0.score(for: metric.id)) })
            let delta = calculateDelta(current: curAvg, previous: prevAvg)

            stats.append(
                SingleMetricStat(
                    metricId: metric.id,
                    name: metric.name,
                    icon: metric.icon,
                    color: metric.color,
                    average: curAvg,
                    delta: delta
                )
            )
        }

        let currentComposite = average(currentRecords.map { $0.compositeScore })
        let prevComposite = average(prevRecords.map { $0.compositeScore })
        let compositeDelta = calculateDelta(current: currentComposite, previous: prevComposite)
        let streak = calculateStreak(records: records)

        return MetricSummary(
            metricStats: stats,
            compositeAvg: currentComposite,
            compositeDelta: compositeDelta,
            totalEntries: currentRecords.count,
            currentStreakDays: streak
        )
    }

    private func emptySummary(metrics: [MetricDefinition]) -> MetricSummary {
        let stats = metrics.map {
            SingleMetricStat(metricId: $0.id, name: $0.name, icon: $0.icon, color: $0.color, average: 0, delta: 0)
        }
        return MetricSummary(
            metricStats: stats,
            compositeAvg: 0, compositeDelta: 0,
            totalEntries: 0, currentStreakDays: 0
        )
    }

    private func average(_ numbers: [Double]) -> Double {
        guard !numbers.isEmpty else { return 0 }
        return numbers.reduce(0, +) / Double(numbers.count)
    }

    private func calculateDelta(current: Double, previous: Double) -> Double {
        guard previous > 0 else { return 0 }
        return ((current - previous) / previous) * 100.0
    }

    // MARK: - Streak
    func calculateStreak(records: [CheckInRecord]) -> Int {
        guard !records.isEmpty else { return 0 }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let datesSet = Set(records.map { calendar.startOfDay(for: $0.timestamp) })

        var streak = 0
        var checkDate = today

        if !datesSet.contains(checkDate) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate),
                  datesSet.contains(yesterday) else {
                return 0
            }
            checkDate = yesterday
        }

        while datesSet.contains(checkDate) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previousDay
        }

        return streak
    }

    // MARK: - Daily Chart Points
    func generateChartPoints(records: [CheckInRecord], period: AnalyticsPeriod, metrics: [MetricDefinition]) -> [DailyChartPoint] {
        let calendar = Calendar.current
        let now = calendar.startOfDay(for: Date())
        let days = period.rawValue

        guard let startDate = calendar.date(byAdding: .day, value: -days + 1, to: now) else { return [] }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var dayMap: [String: [CheckInRecord]] = [:]
        for record in records {
            let key = formatter.string(from: record.timestamp)
            dayMap[key, default: []].append(record)
        }

        var points: [DailyChartPoint] = []
        var currentDate = startDate

        while currentDate <= now {
            let key = formatter.string(from: currentDate)
            let dayRecords = dayMap[key] ?? []

            var metricMap: [String: Double] = [:]
            for metric in metrics {
                metricMap[metric.id] = average(dayRecords.map { Double($0.score(for: metric.id)) })
            }

            let composite = average(dayRecords.map { $0.compositeScore })

            points.append(
                DailyChartPoint(
                    date: currentDate,
                    dateString: key,
                    scoresByMetric: metricMap,
                    composite: composite,
                    movingAverage: nil
                )
            )

            guard let next = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = next
        }

        for i in 0..<points.count {
            let windowStart = max(0, i - 6)
            let window = points[windowStart...i].map { $0.composite }.filter { $0 > 0 }
            if !window.isEmpty {
                points[i].movingAverage = average(window)
            }
        }

        return points
    }

    // MARK: - GitHub-Style Heatmap (52 weeks)
    func generateHeatmap(records: [CheckInRecord]) -> [HeatmapWeek] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2

        let now = Date()
        let today = calendar.startOfDay(for: now)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var dayMap: [String: [CheckInRecord]] = [:]
        for record in records {
            let key = formatter.string(from: record.timestamp)
            dayMap[key, default: []].append(record)
        }

        let totalDays = 52 * 7
        guard let gridStartDate = calendar.date(byAdding: .day, value: -(totalDays - 1), to: today) else {
            return []
        }

        var weeks: [HeatmapWeek] = []
        var currentDays: [HeatmapDay] = []
        var weekCounter = 0

        for dayOffset in 0..<totalDays {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: gridStartDate) else { continue }
            let key = formatter.string(from: date)
            let dayRecords = dayMap[key] ?? []

            let score = average(dayRecords.map { $0.compositeScore })
            let level: Int
            if dayRecords.isEmpty {
                level = 0
            } else {
                switch score {
                case 0..<2.5: level = 1
                case 2.5..<5.0: level = 2
                case 5.0..<7.5: level = 3
                default: level = 4
                }
            }

            let tags = Array(Set(dayRecords.flatMap { $0.tags }))
            let notes = dayRecords.map { $0.note }.filter { !$0.isEmpty }

            let weekday = calendar.component(.weekday, from: date)
            let normalizedWeekday = (weekday == 1) ? 7 : (weekday - 1)

            let heatmapDay = HeatmapDay(
                date: date,
                dateString: key,
                level: level,
                score: score,
                count: dayRecords.count,
                tags: tags,
                notes: notes,
                dayOfWeek: normalizedWeekday,
                records: dayRecords.sorted(by: { $0.timestamp < $1.timestamp })
            )

            currentDays.append(heatmapDay)

            if currentDays.count == 7 {
                weeks.append(HeatmapWeek(weekIndex: weekCounter, days: currentDays))
                currentDays = []
                weekCounter += 1
            }
        }

        if !currentDays.isEmpty {
            weeks.append(HeatmapWeek(weekIndex: weekCounter, days: currentDays))
        }

        return weeks
    }

    // MARK: - Correlation & Insights Engine
    func generateInsights(records: [CheckInRecord]) -> [InsightModel] {
        guard records.count >= 3 else {
            return [
                InsightModel(
                    title: "Накопление данных",
                    description: "Сделайте еще несколько чек-инов, чтобы алгоритм нашел первые персональные закономерности.",
                    deltaPercentage: 0,
                    category: .neutral,
                    factorName: "Общие данные"
                )
            ]
        }

        var insights: [InsightModel] = []

        var allTags = Set<String>()
        for r in records {
            allTags.formUnion(r.tags)
        }

        for tag in allTags {
            let withTag = records.filter { $0.tags.contains(tag) }
            let withoutTag = records.filter { !$0.tags.contains(tag) }

            guard withTag.count >= 2 && !withoutTag.isEmpty else { continue }

            let mindWith = average(withTag.map { Double($0.mentalResource) })
            let mindWithout = average(withoutTag.map { Double($0.mentalResource) })
            let mindDelta = calculateDelta(current: mindWith, previous: mindWithout)

            let bodyWith = average(withTag.map { Double($0.bodyEnergy) })
            let bodyWithout = average(withoutTag.map { Double($0.bodyEnergy) })
            let bodyDelta = calculateDelta(current: bodyWith, previous: bodyWithout)

            let focusWith = average(withTag.map { Double($0.focus) })
            let focusWithout = average(withoutTag.map { Double($0.focus) })
            let focusDelta = calculateDelta(current: focusWith, previous: focusWithout)

            let deltas = [("моральный ресурс", mindDelta), ("физическую энергию", bodyDelta), ("фокус и ясность", focusDelta)]
            if let maxDelta = deltas.max(by: { abs($0.1) < abs($1.1) }), abs(maxDelta.1) >= 8.0 {
                let isPositive = maxDelta.1 > 0
                let percentageStr = String(format: "%.0f%%", abs(maxDelta.1))
                let directionWord = isPositive ? "выше на" : "ниже на"

                let title = "Тег [\(tag)]"
                let description = "В дни с отметкой «\(tag)» \(maxDelta.0) в среднем \(directionWord) \(percentageStr)."

                insights.append(
                    InsightModel(
                        title: title,
                        description: description,
                        deltaPercentage: maxDelta.1,
                        category: isPositive ? .positive : .negative,
                        factorName: tag
                    )
                )
            }
        }

        // 2. Screen Time Correlation
        let recordsWithScreen = records.filter { $0.screenTimeSeconds > 0 }
        if recordsWithScreen.count >= 4 {
            let heavyScreenDays = recordsWithScreen.filter { $0.screenTimeSeconds >= 8 * 3600 }
            let normalScreenDays = recordsWithScreen.filter { $0.screenTimeSeconds < 8 * 3600 }

            if !heavyScreenDays.isEmpty && !normalScreenDays.isEmpty {
                let heavyFocus = average(heavyScreenDays.map { Double($0.focus) })
                let normalFocus = average(normalScreenDays.map { Double($0.focus) })
                let focusDelta = calculateDelta(current: heavyFocus, previous: normalFocus)

                if focusDelta < -5.0 {
                    let percent = String(format: "%.0f%%", abs(focusDelta))
                    insights.append(
                        InsightModel(
                            title: "Экранное время за Mac",
                            description: "При работе за компьютером более 8 часов фокус и концентрация снижаются на \(percent). Делайте короткие паузы.",
                            deltaPercentage: focusDelta,
                            category: .screenTime,
                            factorName: "Экранное время"
                        )
                    )
                }
            }
        }

        insights.sort { abs($0.deltaPercentage) > abs($1.deltaPercentage) }

        if insights.isEmpty {
            insights.append(
                InsightModel(
                    title: "Баланс в норме",
                    description: "Пока показатели распределены равномерно. Продолжайте отмечать теги и контекст, чтобы выявить скрытые тренды.",
                    deltaPercentage: 0,
                    category: .neutral,
                    factorName: "Общие данные"
                )
            )
        }

        return insights
    }

    // MARK: - Intraday Phase Stats
    func calculatePhaseStats(records: [CheckInRecord], metrics: [MetricDefinition]) -> [IntradayPhaseStat] {
        return TimeOfDayPhase.allCases.map { phase in
            let phaseRecords = records.filter { $0.phase == phase }
            let avgScore = average(phaseRecords.map { $0.compositeScore })

            var metricAvgs: [String: Double] = [:]
            for metric in metrics {
                metricAvgs[metric.id] = average(phaseRecords.map { Double($0.score(for: metric.id)) })
            }

            return IntradayPhaseStat(
                phase: phase,
                averageScore: avgScore,
                checkInCount: phaseRecords.count,
                metricAverages: metricAvgs
            )
        }
    }

    // MARK: - 24-Hour Hourly Curve
    func generateHourlyCurve(records: [CheckInRecord], metrics: [MetricDefinition]) -> [HourlyCurvePoint] {
        let calendar = Calendar.current
        var hourlyBuckets: [Int: [CheckInRecord]] = [:]

        for record in records {
            let hour = calendar.component(.hour, from: record.timestamp)
            hourlyBuckets[hour, default: []].append(record)
        }

        let hoursRange = Array(6...23)
        return hoursRange.map { hour in
            let hourRecords = hourlyBuckets[hour] ?? []
            let label = String(format: "%02d:00", hour)
            let comp = average(hourRecords.map { $0.compositeScore })

            var metricMap: [String: Double] = [:]
            for metric in metrics {
                metricMap[metric.id] = average(hourRecords.map { Double($0.score(for: metric.id)) })
            }

            return HourlyCurvePoint(
                hour: hour,
                hourLabel: label,
                composite: comp,
                metricScores: metricMap,
                sampleCount: hourRecords.count
            )
        }
    }
}

import SwiftUI

struct HistoryFeedView: View {
    @Binding var checkIns: [CheckInRecord]
    var onRecordUpdated: () -> Void

    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var searchText: String = ""
    @State private var selectedFilterTag: String? = nil
    @State private var editingRecord: CheckInRecord? = nil

    private var theme: AppTheme {
        themeManager.theme
    }

    private var allTags: [String] {
        var tagsSet = Set<String>()
        for r in checkIns {
            tagsSet.formUnion(r.tags)
        }
        return Array(tagsSet).sorted()
    }

    private var filteredCheckIns: [CheckInRecord] {
        checkIns.filter { record in
            let matchesSearch = searchText.isEmpty ||
                record.note.localizedCaseInsensitiveContains(searchText) ||
                record.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })

            let matchesTag = selectedFilterTag == nil || record.tags.contains(selectedFilterTag!)

            return matchesSearch && matchesTag
        }
    }

    // Group records by day string
    private var groupedRecords: [(key: String, records: [CheckInRecord])] {
        var dict: [String: [CheckInRecord]] = [:]
        for r in filteredCheckIns {
            dict[r.dateString, default: []].append(r)
        }
        return dict.sorted(by: { $0.key > $1.key }).map { (key: $0.key, records: $0.value) }
    }

    var body: some View {
        VStack(spacing: 14) {
            // Filter & Search Header
            HStack(spacing: 12) {
                // Search Field
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSecondary)

                    TextField("Поиск по заметкам и тегам...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(theme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(theme.cardBorder, lineWidth: 1)
                        )
                )

                Spacer()

                // Tag Filter Picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        filterTagButton(title: "Все", isSelected: selectedFilterTag == nil) {
                            selectedFilterTag = nil
                        }

                        ForEach(allTags, id: \.self) { tag in
                            filterTagButton(title: tag, isSelected: selectedFilterTag == tag) {
                                selectedFilterTag = (selectedFilterTag == tag) ? nil : tag
                            }
                        }
                    }
                }
                .frame(maxWidth: 380)
            }

            // Entries List
            if groupedRecords.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundColor(theme.textSecondary)
                    Text("Записей не найдено")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 60)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(groupedRecords, id: \.key) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                // Day Header
                                Text(formatGroupDate(group.key))
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(theme.textSecondary)
                                    .padding(.leading, 4)

                                // Records in this day
                                VStack(spacing: 8) {
                                    ForEach(group.records) { record in
                                        recordRow(record: record)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .sheet(item: $editingRecord) { recordToEdit in
            EditCheckInSheet(
                record: Binding(
                    get: { recordToEdit },
                    set: { editingRecord = $0 }
                ),
                onSave: { updated in
                    DatabaseManager.shared.saveCheckIn(updated)
                    editingRecord = nil
                    onRecordUpdated()
                },
                onCancel: {
                    editingRecord = nil
                }
            )
        }
    }

    @ViewBuilder
    private func filterTagButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isSelected ? theme.accent : theme.cardBackground)
                        .overlay(
                            Capsule()
                                .stroke(theme.cardBorder, lineWidth: 1)
                        )
                )
                .foregroundColor(isSelected ? theme.accentText : theme.textPrimary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func recordRow(record: CheckInRecord) -> some View {
        HStack(alignment: .center, spacing: 14) {
            // Time
            Text(record.timeString)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(theme.textSecondary)
                .frame(width: 44, alignment: .leading)

            // Dynamic Scores
            HStack(spacing: 6) {
                ForEach(MetricManager.shared.metrics) { metric in
                    let val = record.score(for: metric.id)
                    let firstLetter = String(metric.name.prefix(1)).uppercased()
                    metricPill(label: firstLetter, value: val, color: metric.color)
                }
            }

            // Tags
            if !record.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(record.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.cardBorder.opacity(0.6))
                            .clipShape(Capsule())
                            .foregroundColor(theme.textPrimary)
                    }
                }
            }

            // Note
            if !record.note.isEmpty {
                Text(record.note)
                    .font(.system(size: 12))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Active Screen Time
            if record.screenTimeSeconds > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "display")
                        .font(.system(size: 9))
                    Text("\(record.screenTimeSeconds / 3600)ч \((record.screenTimeSeconds % 3600) / 60)м")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(theme.textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(theme.background)
                .cornerRadius(4)
            }

            // Edit & Delete Actions
            HStack(spacing: 6) {
                Button(action: {
                    editingRecord = record
                }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                        .foregroundColor(theme.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Редактировать")

                Button(action: {
                    deleteRecord(record)
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(theme.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Удалить")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(theme.cardBorder, lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func metricPill(label: String, value: Int, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(color)

            Text("\(value)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(theme.textPrimary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private func deleteRecord(_ record: CheckInRecord) {
        DatabaseManager.shared.deleteCheckIn(id: record.id)
        onRecordUpdated()
    }

    private func formatGroupDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }

        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Сегодня"
        } else if calendar.isDateInYesterday(date) {
            return "Вчера"
        } else {
            let displayFormatter = DateFormatter()
            displayFormatter.locale = Locale(identifier: "ru_RU")
            displayFormatter.dateFormat = "EEEE, d MMMM yyyy"
            let str = displayFormatter.string(from: date)
            return str.prefix(1).uppercased() + str.dropFirst()
        }
    }
}

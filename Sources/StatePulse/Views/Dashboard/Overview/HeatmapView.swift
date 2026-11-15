import SwiftUI

struct HeatmapView: View {
    let weeks: [HeatmapWeek]

    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var hoveredDay: HeatmapDay?
    @State private var selectedDay: HeatmapDay?

    private var theme: AppTheme {
        themeManager.theme
    }

    private var allDays: [HeatmapDay] {
        weeks.flatMap { $0.days }
    }

    private var activeDay: HeatmapDay? {
        if let hovered = hoveredDay {
            return hovered
        }
        if let selected = selectedDay {
            return selected
        }
        return allDays.last(where: { $0.count > 0 }) ?? allDays.last
    }

    private let dayLabels = ["Пн", "", "Ср", "", "Пт", "", ""]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Тепловая карта года")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(theme.textPrimary)

                    Text("Календарный баланс состояния день за днем")
                        .font(.system(size: 11))
                        .foregroundColor(theme.textSecondary)
                }

                Spacer()

                // Legend
                HStack(spacing: 5) {
                    Text("Меньше")
                        .font(.system(size: 10))
                        .foregroundColor(theme.textSecondary)

                    HStack(spacing: 3) {
                        ForEach(0...4, id: \.self) { level in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(theme.heatmapColor(level: level))
                                .frame(width: 10, height: 10)
                        }
                    }

                    Text("Больше")
                        .font(.system(size: 10))
                        .foregroundColor(theme.textSecondary)
                }
            }

            // Heatmap Grid with ScrollView
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 6) {
                    // Weekday Labels
                    VStack(spacing: 3) {
                        ForEach(0..<7, id: \.self) { i in
                            Text(dayLabels[i])
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(theme.textSecondary)
                                .frame(width: 18, height: 11, alignment: .leading)
                        }
                    }

                    // Weeks Columns
                    HStack(spacing: 3) {
                        ForEach(weeks) { week in
                            VStack(spacing: 3) {
                                ForEach(week.days) { day in
                                    dayCell(day: day)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // Selected / Hovered Day Details Card
            if let day = activeDay {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(formatDayTitle(day))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(theme.textPrimary)

                            if day.count > 0 {
                                Text("Индекс дня: \(String(format: "%.1f", day.score)) / 10 • \(day.count) чек-ин(а/ов)")
                                    .font(.system(size: 11))
                                    .foregroundColor(theme.textSecondary)
                            } else {
                                Text("Нет записей в этот день")
                                    .font(.system(size: 11))
                                    .foregroundColor(theme.textSecondary)
                            }
                        }

                        Spacer()
                    }

                    if !day.records.isEmpty {
                        VStack(spacing: 6) {
                            ForEach(day.records) { record in
                                recordRow(record: record)
                            }
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(theme.background)
                        .overlay(
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(theme.cardBorder, lineWidth: 1)
                        )
                )
                .transition(.opacity)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.cardBorder, lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func recordRow(record: CheckInRecord) -> some View {
        HStack(alignment: .center, spacing: 10) {
            // Time & Phase
            HStack(spacing: 4) {
                Image(systemName: record.phase.icon)
                    .font(.system(size: 9))
                    .foregroundColor(record.phase.color)
                Text(record.timeString)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(theme.textPrimary)
                Text(record.phase.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(theme.textSecondary)
            }
            .frame(minWidth: 95, alignment: .leading)

            // Dynamic Metric Scores
            HStack(spacing: 5) {
                ForEach(MetricManager.shared.metrics) { metric in
                    let val = record.score(for: metric.id)
                    let firstLetter = String(metric.name.prefix(1)).uppercased()
                    HStack(spacing: 2) {
                        Text(firstLetter)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(metric.color)
                        Text("\(val)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(theme.textPrimary)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(metric.color.opacity(0.12))
                    .clipShape(Capsule())
                }
            }

            // Tags
            if !record.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(record.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(theme.cardBorder.opacity(0.6))
                            .clipShape(Capsule())
                            .foregroundColor(theme.textPrimary)
                    }
                }
            }

            // Note
            if !record.note.isEmpty {
                Text("\"\(record.note)\"")
                    .font(.system(size: 11))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Active Screen Time (if present)
            if record.screenTimeSeconds > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "display")
                        .font(.system(size: 8))
                    Text("\(record.screenTimeSeconds / 3600)ч \((record.screenTimeSeconds % 3600) / 60)м")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundColor(theme.textSecondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(theme.cardBackground)
                .cornerRadius(4)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(theme.cardBorder.opacity(0.7), lineWidth: 0.8)
                )
        )
    }

    @ViewBuilder
    private func dayCell(day: HeatmapDay) -> some View {
        let isHovered = hoveredDay?.id == day.id
        let isSelected = activeDay?.id == day.id

        RoundedRectangle(cornerRadius: 2.5)
            .fill(theme.heatmapColor(level: day.level))
            .frame(width: 11, height: 11)
            .overlay(
                RoundedRectangle(cornerRadius: 2.5)
                    .stroke(isSelected ? theme.accent : (isHovered ? theme.textPrimary : Color.clear), lineWidth: 1.5)
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.12)) {
                    if hovering {
                        hoveredDay = day
                    } else if hoveredDay?.id == day.id {
                        hoveredDay = nil
                    }
                }
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                    selectedDay = day
                }
            }
    }

    private func formatDayTitle(_ day: HeatmapDay) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day.date) {
            return "Сегодня, \(formatFullDate(day.date))"
        } else if calendar.isDateInYesterday(day.date) {
            return "Вчера, \(formatFullDate(day.date))"
        } else {
            return formatFullDate(day.date)
        }
    }

    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy, EEEE"
        let str = formatter.string(from: date)
        return str.prefix(1).uppercased() + str.dropFirst()
    }
}

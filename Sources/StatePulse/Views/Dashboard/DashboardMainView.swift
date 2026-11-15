import SwiftUI

enum DashboardTab: String, CaseIterable, Identifiable {
    case overview = "overview"
    case intraday = "intraday"
    case history = "history"
    case settings = "settings"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Обзор"
        case .intraday: return "Ритм дня"
        case .history: return "История"
        case .settings: return "Настройки"
        }
    }

    var icon: String {
        switch self {
        case .overview: return "chart.bar.xaxis"
        case .intraday: return "sun.horizon.fill"
        case .history: return "clock.arrow.circlepath"
        case .settings: return "gearshape"
        }
    }
}

struct DashboardMainView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    @State private var selectedTab: DashboardTab = .overview
    @State private var selectedPeriod: AnalyticsPeriod = .days30
    @State private var checkIns: [CheckInRecord] = []

    private var theme: AppTheme {
        themeManager.theme
    }

    private var summary: MetricSummary {
        AnalyticsEngine.shared.calculateSummary(records: checkIns, period: selectedPeriod, metrics: MetricManager.shared.metrics)
    }

    private var heatmapWeeks: [HeatmapWeek] {
        AnalyticsEngine.shared.generateHeatmap(records: checkIns)
    }

    private var chartPoints: [DailyChartPoint] {
        AnalyticsEngine.shared.generateChartPoints(records: checkIns, period: selectedPeriod, metrics: MetricManager.shared.metrics)
    }

    private var insights: [InsightModel] {
        AnalyticsEngine.shared.generateInsights(records: checkIns)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top Navigation & Window Header
            HStack(spacing: 16) {
                // App Branding
                HStack(spacing: 8) {
                    Circle()
                        .fill(theme.accent)
                        .frame(width: 10, height: 10)

                    Text("StatePulse")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                }

                Spacer()

                // Clean Tab Selector
                HStack(spacing: 4) {
                    ForEach(DashboardTab.allCases) { tab in
                        let isSelected = selectedTab == tab
                        Button(action: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                selectedTab = tab
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                                Text(tab.title)
                                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(isSelected ? theme.accent : Color.clear)
                            )
                            .foregroundColor(isSelected ? theme.accentText : theme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(
                    Capsule()
                        .fill(theme.cardBackground)
                        .overlay(
                            Capsule()
                                .stroke(theme.cardBorder, lineWidth: 1)
                        )
                )

                Spacer()

                // Current Streak Badge
                let streak = AnalyticsEngine.shared.calculateStreak(records: checkIns)
                if streak > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                        Text("\(streak) дн подряд")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(theme.cardBackground)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(theme.cardBorder),
                alignment: .bottom
            )

            // Tab Content
            Group {
                switch selectedTab {
                case .overview:
                    ScrollView {
                        VStack(spacing: 20) {
                            MetricSummaryCardsView(
                                summary: summary,
                                selectedPeriod: $selectedPeriod
                            )

                            HeatmapView(weeks: heatmapWeeks)

                            TrendChartView(points: chartPoints)

                            InsightsListView(insights: insights)
                        }
                        .padding(24)
                    }

                case .intraday:
                    IntradayView(checkIns: checkIns)

                case .history:
                    HistoryFeedView(
                        checkIns: $checkIns,
                        onRecordUpdated: reloadData
                    )
                    .padding(24)

                case .settings:
                    SettingsView(onDataChanged: reloadData)
                }
            }
        }
        .frame(minWidth: 860, minHeight: 620)
        .background(theme.background)
        .preferredColorScheme(themeManager.colorScheme)
        .onAppear {
            reloadData()
            Task {
                await CloudSyncService.shared.syncAll()
            }
        }
        .onChange(of: selectedTab) { _, _ in
            Task {
                await CloudSyncService.shared.syncAll()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .databaseDidChange)) { _ in
            reloadData()
        }
    }

    private func reloadData() {
        checkIns = DatabaseManager.shared.fetchAllCheckIns()
    }
}

import SwiftUI

struct SettingsView: View {
    var onDataChanged: () -> Void

    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var metricManager = MetricManager.shared
    @ObservedObject private var notificationService = NotificationService.shared
    @ObservedObject private var passiveTracker = PassiveTrackerService.shared
    @ObservedObject private var launchAtLogin = LaunchAtLoginService.shared

    @State private var newReminderHour: Int = 12
    @State private var newReminderMinute: Int = 0
    @State private var showClearConfirmAlert: Bool = false
    @State private var statusMessage: String? = nil

    @State private var editingMetric: MetricDefinition? = nil
    @State private var isAddingNewMetric: Bool = false

    private var theme: AppTheme {
        themeManager.theme
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Status Toast
                if let msg = statusMessage {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(msg)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                    }
                    .padding(10)
                    .background(theme.cardBackground)
                    .cornerRadius(8)
                    .transition(.opacity)
                }

                // 1. Appearance
                settingsSection(title: "Внешний вид", icon: "paintbrush.fill") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Тема оформления")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(theme.textPrimary)
                            Spacer()

                            Picker("", selection: $themeManager.themeMode) {
                                ForEach(ThemeMode.allCases) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 220)
                        }

                        Text("Вы можете зафиксировать мягкую светлую тему (Soft White), глубокую темную (Soft Black) или следовать за macOS.")
                            .font(.system(size: 11))
                            .foregroundColor(theme.textSecondary)
                    }
                }

                // 2. Metric Customization
                settingsSection(title: "Шкалы оценки (Метрики)", icon: "slider.horizontal.3") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Настройте названия, иконки и цвета шкал под себя, добавляйте свои шкалы или удаляйте ненужные.")
                            .font(.system(size: 11))
                            .foregroundColor(theme.textSecondary)

                        VStack(spacing: 8) {
                            ForEach(metricManager.metrics) { metric in
                                HStack(spacing: 10) {
                                    Image(systemName: metric.icon)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(metric.color)
                                        .frame(width: 20)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(metric.name)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(theme.textPrimary)

                                        if !metric.subtitle.isEmpty {
                                            Text(metric.subtitle)
                                                .font(.system(size: 10))
                                                .foregroundColor(theme.textSecondary)
                                        }
                                    }

                                    Spacer()

                                    Circle()
                                        .fill(metric.color)
                                        .frame(width: 12, height: 12)

                                    Button(action: {
                                        editingMetric = metric
                                    }) {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 12))
                                            .foregroundColor(theme.textSecondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Изменить название, иконку или цвет")

                                    if metricManager.metrics.count > 1 {
                                        Button(action: {
                                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                                metricManager.deleteMetric(id: metric.id)
                                                onDataChanged()
                                            }
                                        }) {
                                            Image(systemName: "trash")
                                                .font(.system(size: 12))
                                                .foregroundColor(theme.textSecondary)
                                        }
                                        .buttonStyle(.plain)
                                        .help("Удалить шкалу")
                                    }
                                }
                                .padding(10)
                                .background(theme.background)
                                .cornerRadius(8)
                            }
                        }

                        Divider()

                        HStack(spacing: 12) {
                            Button(action: {
                                isAddingNewMetric = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                    Text("Добавить новую шкалу")
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(theme.accent)
                                .foregroundColor(theme.accentText)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Button("Восстановить стандартные шкалы") {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    metricManager.resetToDefault()
                                    onDataChanged()
                                    showStatus("Стандартные шкалы восстановлены")
                                }
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(theme.textSecondary)
                        }
                    }
                }

                // 3. Smart Reminders
                settingsSection(title: "Умные напоминания", icon: "bell.fill") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Системные уведомления")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(theme.textPrimary)

                                Text(notificationService.isNotificationsAuthorized ? "Разрешены в macOS" : "Требуется разрешение в Настройках macOS")
                                    .font(.system(size: 11))
                                    .foregroundColor(notificationService.isNotificationsAuthorized ? .green : .orange)
                            }

                            Spacer()

                            if !notificationService.isNotificationsAuthorized {
                                Button("Разрешить") {
                                    notificationService.requestAuthorization()
                                }
                                .buttonStyle(.borderedProminent)
                            } else {
                                Button("Тестовое уведомление") {
                                    notificationService.sendTestNotification()
                                    showStatus("Тестовое уведомление отправлено!")
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 11))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(theme.background)
                                .cornerRadius(6)
                            }
                        }

                        Divider()

                        Text("Расписание напоминаний чек-ина:")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(theme.textPrimary)

                        ForEach(notificationService.reminders) { reminder in
                            HStack {
                                Text(reminder.displayString)
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(theme.textPrimary)

                                Spacer()

                                Toggle("", isOn: Binding(
                                    get: { reminder.isEnabled },
                                    set: { _ in notificationService.toggleReminder(id: reminder.id) }
                                ))
                                .toggleStyle(.switch)

                                Button(action: {
                                    notificationService.deleteReminder(id: reminder.id)
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                        .foregroundColor(theme.textSecondary)
                                }
                                .buttonStyle(.plain)
                                .padding(.leading, 6)
                            }
                        }

                        // Add new reminder row
                        HStack(spacing: 8) {
                            Text("Добавить:")
                                .font(.system(size: 11))
                                .foregroundColor(theme.textSecondary)

                            Picker("", selection: $newReminderHour) {
                                ForEach(0..<24, id: \.self) { h in
                                    Text(String(format: "%02d", h)).tag(h)
                                }
                            }
                            .frame(width: 60)

                            Text(":")

                            Picker("", selection: $newReminderMinute) {
                                ForEach([0, 15, 30, 45], id: \.self) { m in
                                    Text(String(format: "%02d", m)).tag(m)
                                }
                            }
                            .frame(width: 60)

                            Button("Добавить") {
                                notificationService.addReminder(hour: newReminderHour, minute: newReminderMinute)
                                showStatus("Напоминание добавлено")
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(theme.accent)
                            .foregroundColor(theme.accentText)
                            .cornerRadius(6)
                        }
                    }
                }

                // 4. Passive Screen Time Context & Autostart
                settingsSection(title: "Автоматизация и система", icon: "laptopcomputer") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Экранное время Mac")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(theme.textPrimary)

                                Text("Локальная фиксация активности без фоновых опросов процессора")
                                    .font(.system(size: 11))
                                    .foregroundColor(theme.textSecondary)
                            }

                            Spacer()

                            Text(passiveTracker.formattedScreenTime)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(theme.textPrimary)
                        }

                        Divider()

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Горячая клавиша быстрого вызова")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(theme.textPrimary)

                                Text("Открывает чек-ин из любого приложения")
                                    .font(.system(size: 11))
                                    .foregroundColor(theme.textSecondary)
                            }

                            Spacer()

                            Text("⌥ Space (Option + Space)")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(theme.background)
                                .cornerRadius(6)
                                .foregroundColor(theme.textPrimary)
                        }

                        Divider()

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Запуск при входе в систему (macOS)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(theme.textPrimary)

                                Text("StatePulse будет автоматически готов в строке меню")
                                    .font(.system(size: 11))
                                    .foregroundColor(theme.textSecondary)
                            }

                            Spacer()

                            Toggle("", isOn: Binding(
                                get: { launchAtLogin.isEnabled },
                                set: { _ in launchAtLogin.toggle() }
                            ))
                            .toggleStyle(.switch)
                        }
                    }
                }

                // 5. Data Management & Backup
                settingsSection(title: "Данные и резервное копирование", icon: "externaldrive.fill") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Все ваши чек-ины и контекст хранятся исключительно на этом Mac в защищенной локальной базе SQLite.")
                            .font(.system(size: 11))
                            .foregroundColor(theme.textSecondary)

                        HStack(spacing: 10) {
                            Button(action: {
                                DataExporter.shared.exportToJSON()
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Экспорт в JSON")
                                }
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(theme.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(theme.cardBorder, lineWidth: 1)
                                )
                                .foregroundColor(theme.textPrimary)
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                DataExporter.shared.exportToCSV()
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "tablecells")
                                    Text("Экспорт в CSV")
                                }
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(theme.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(theme.cardBorder, lineWidth: 1)
                                )
                                .foregroundColor(theme.textPrimary)
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                let res = DataExporter.shared.importFromJSON()
                                if res.success {
                                    showStatus("Успешно импортировано \(res.count) записей")
                                    onDataChanged()
                                }
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "square.and.arrow.down")
                                    Text("Импорт из JSON")
                                }
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(theme.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(theme.cardBorder, lineWidth: 1)
                                )
                                .foregroundColor(theme.textPrimary)
                            }
                            .buttonStyle(.plain)
                        }

                        Divider()

                        HStack {
                            Button(action: {
                                UserDefaults.standard.removeObject(forKey: "statepulse_hidden_preset_tags")
                                onDataChanged()
                                showStatus("Стандартные теги восстановлены")
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Восстановить стандартные теги")
                                }
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(theme.textSecondary)
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Button(action: {
                                MockDataGenerator.generateSampleData(daysCount: 35)
                                onDataChanged()
                                showStatus("Демо-данные за 35 дней успешно добавлены!")
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "wand.and.stars")
                                    Text("Сгенерировать демо-данные")
                                }
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(theme.textSecondary)
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                showClearConfirmAlert = true
                            }) {
                                Text("Очистить всё")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // 6. App Info Footer
                HStack {
                    Spacer()
                    VStack(spacing: 2) {
                        Text("StatePulse • Версия 1.0 (Apple Silicon Native)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(theme.textSecondary)
                        Text("100% локально • Минимальное потребление памяти")
                            .font(.system(size: 10))
                            .foregroundColor(theme.textSecondary.opacity(0.8))
                    }
                    Spacer()
                }
                .padding(.top, 10)
            }
            .padding(20)
        }
        .sheet(item: $editingMetric) { metric in
            EditMetricSheet(metricToEdit: metric) {
                editingMetric = nil
                onDataChanged()
            }
        }
        .sheet(isPresented: $isAddingNewMetric) {
            EditMetricSheet(metricToEdit: nil) {
                isAddingNewMetric = false
                onDataChanged()
            }
        }
        .alert("Очистить все данные?", isPresented: $showClearConfirmAlert) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить всё", role: .destructive) {
                DatabaseManager.shared.clearAllData()
                onDataChanged()
                showStatus("Все данные удалены")
            }
        } message: {
            Text("Это действие безвозвратно удалит все сохраненные чек-ины и контекст.")
        }
    }

    @ViewBuilder
    private func settingsSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.textPrimary)

                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(theme.textPrimary)
            }

            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.cardBorder, lineWidth: 1)
                )
            )
        }
    }

    private func showStatus(_ msg: String) {
        withAnimation {
            statusMessage = msg
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation {
                if statusMessage == msg {
                    statusMessage = nil
                }
            }
        }
    }
}

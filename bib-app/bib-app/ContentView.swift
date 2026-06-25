import CoreData
import SwiftUI

enum AppStyle {
    static let orange = Color(hex: 0xff7700)
    static let teal = Color(hex: 0x009393)
    static let lime = Color(hex: 0xafca0b)
    static let magenta = Color(hex: 0xe50b7c)
    static let blue = Color(hex: 0x12719f)

    static let background = Color(.systemGroupedBackground)
    static let surface = Color(.secondarySystemGroupedBackground)
    static let elevatedSurface = Color(.tertiarySystemGroupedBackground)
    static let primaryText = Color(.label)
    static let secondaryText = Color(.secondaryLabel)

    static let brandGradient = LinearGradient(
        colors: [orange, magenta, teal],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let subjectPalette = [orange, teal, lime, magenta, blue]

    static func subjectColor(for code: String?) -> Color {
        guard let code else {
            return teal
        }

        let total = code.unicodeScalars.reduce(0) { partialResult, scalar in
            partialResult + Int(scalar.value)
        }

        return subjectPalette[abs(total) % subjectPalette.count]
    }
}

extension Color {
    init(hex: Int, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: opacity
        )
    }
}

extension Font {
    static let interLargeTitle = Font.custom("Inter", size: 34, relativeTo: .largeTitle).weight(.bold)
    static let interTitle = Font.custom("Inter", size: 28, relativeTo: .title).weight(.bold)
    static let interTitle2 = Font.custom("Inter", size: 22, relativeTo: .title2).weight(.semibold)
    static let interTitle3 = Font.custom("Inter", size: 20, relativeTo: .title3).weight(.semibold)
    static let interHeadline = Font.custom("Inter", size: 17, relativeTo: .headline).weight(.semibold)
    static let interBody = Font.custom("Inter", size: 17, relativeTo: .body)
    static let interSubheadline = Font.custom("Inter", size: 15, relativeTo: .subheadline)
    static let interCaption = Font.custom("Inter", size: 12, relativeTo: .caption)
    static let interCaption2 = Font.custom("Inter", size: 11, relativeTo: .caption2)
}

struct ContentView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Calendar.timestamp, ascending: false)],
        animation: .default
    )
    private var calendars: FetchedResults<Calendar>

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedTab: CalendarTab = .today
    @State private var selectedWeekDate = Date()

    var body: some View {
        VStack(spacing: 0) {
            selectedView
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
                .overlay(AppStyle.teal.opacity(0.22))

            HStack(spacing: 0) {
                BottomMenuButton(
                    tab: .today,
                    isSelected: selectedTab == .today,
                    action: { select(.today) }
                )
                BottomMenuButton(
                    tab: .changes,
                    isSelected: selectedTab == .changes,
                    action: { select(.changes) }
                )
                BottomMenuButton(
                    tab: .week,
                    isSelected: selectedTab == .week,
                    action: { select(.week) }
                )
                BottomMenuButton(
                    tab: .exams,
                    isSelected: selectedTab == .exams,
                    action: { select(.exams) }
                )
                BottomMenuButton(
                    tab: .profile,
                    isSelected: selectedTab == .profile,
                    action: { select(.profile) }
                )
            }
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(AppStyle.surface)
            .shadow(color: AppStyle.blue.opacity(0.08), radius: 12, y: -4)
        }
        .background(AppStyle.background)
    }

    @ViewBuilder
    private var selectedView: some View {
        switch selectedTab {
        case .week:
            WeekScheduleView(events: allEvents, selectedWeekDate: $selectedWeekDate)
        case .today:
            TodayView(
                nextEvent: nextEvent,
                laterTodayEvents: laterTodayEvents,
                isLoading: isLoading,
                errorMessage: errorMessage,
                importCalendar: importCalendar
            )
        case .exams:
            ExamsView(events: upcomingExams)
        case .changes:
            ChangesView(events: changeEvents)
        case .profile:
            ProfileView()
        }
    }

    private func select(_ tab: CalendarTab) {
        selectedTab = tab

        switch tab {
        case .week:
            selectedWeekDate = Date()
        case .today:
            break
        case .exams:
            break
        case .changes:
            break
        case .profile:
            break
        }
    }

    private func importCalendar() {
        isLoading = true
        errorMessage = nil

        Task { @MainActor in
            defer {
                isLoading = false
            }

            do {
                try await Shared.item.dataController.loadCalendar()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private var allEvents: [CalendarEvent] {
        storedEvents
            .filter(\.isVisibleInSchedule)
    }

    private var storedEvents: [CalendarEvent] {
        calendars
            .flatMap { calendar in
                calendar.events?.allObjects as? [CalendarEvent] ?? []
            }
            .sorted {
                ($0.start ?? .distantFuture) < ($1.start ?? .distantFuture)
            }
    }

    private var nextEvent: CalendarEvent? {
        let now = Date()
        return allEvents.first { event in
            guard let start = event.start else {
                return false
            }

            return start >= now
        }
    }

    private var todaysEvents: [CalendarEvent] {
        let calendar = Foundation.Calendar.current
        return allEvents.filter { event in
            guard let start = event.start else {
                return false
            }

            return calendar.isDateInToday(start)
        }
    }

    private var laterTodayEvents: [CalendarEvent] {
        guard let nextStart = nextEvent?.start else {
            return todaysEvents
        }

        return todaysEvents.filter { event in
            guard let start = event.start else {
                return false
            }

            return start > nextStart
        }
    }

    private var upcomingExams: [CalendarEvent] {
        let now = Date()
        return allEvents.filter { event in
            guard let start = event.start else {
                return false
            }

            return event.isExam && start >= now
        }
        .sorted {
            ($0.start ?? .distantFuture) < ($1.start ?? .distantFuture)
        }
    }

    private var changeEvents: [CalendarEvent] {
        storedEvents.filter(\.hasChangeLabel)
    }
}

enum CalendarTab {
    case week
    case today
    case exams
    case changes
    case profile

    var title: String {
        switch self {
        case .week:
            return "Woche"
        case .today:
            return "Heute"
        case .exams:
            return "Klausuren"
        case .changes:
            return "Änderungen"
        case .profile:
            return "Profil"
        }
    }

    var systemImage: String {
        switch self {
        case .week:
            return "calendar"
        case .today:
            return "house"
        case .exams:
            return "exclamationmark.square"
        case .changes:
            return "bell.badge"
        case .profile:
            return "person.crop.circle"
        }
    }
}

struct BottomMenuButton: View {
    let tab: CalendarTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(height: 20)

                Text(tab.title)
                    .font(.interCaption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? AppStyle.orange : AppStyle.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background {
                if isSelected {
                    Capsule()
                        .fill(AppStyle.orange.opacity(0.12))
                        .padding(.horizontal, 7)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
    }
}

struct TodayView: View {
    let nextEvent: CalendarEvent?
    let laterTodayEvents: [CalendarEvent]
    let isLoading: Bool
    let errorMessage: String?
    let importCalendar: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(AppStyle.magenta)
                    }
                }

                Section("Nächstes Fach") {
                    if let event = nextEvent {
                        EventNavigationRow(event: event, showsTodayDetails: true, addsVerticalSpacing: true)
                    } else {
                        Text("Kein kommender Kurs gespeichert")
                            .foregroundStyle(AppStyle.secondaryText)
                    }
                }

                Section("Kurse danach") {
                    if laterTodayEvents.isEmpty {
                        Text("Keine weiteren Kurse für heute gespeichert")
                            .foregroundStyle(AppStyle.secondaryText)
                    } else {
                        ForEach(laterTodayEvents, id: \.objectID) { event in
                            EventNavigationRow(event: event, addsVerticalSpacing: true)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppStyle.background)
            .font(.interBody)
            .navigationTitle("Kalender")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button {
                            importCalendar()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .accessibilityLabel("Kalender aktualisieren")
                    }
                }
            }
        }
    }
}

struct ExamsView: View {
    let events: [CalendarEvent]

    var body: some View {
        NavigationStack {
            List {
                Section("Kommende Klausuren") {
                    if events.isEmpty {
                        Text("Keine kommenden Klausuren gespeichert")
                            .foregroundStyle(AppStyle.secondaryText)
                    } else {
                        ForEach(events, id: \.objectID) { event in
                            EventNavigationRow(event: event, showsDate: true, showsTodayDetails: true, addsVerticalSpacing: true)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppStyle.background)
            .font(.interBody)
            .navigationTitle("Klausuren")
        }
    }
}

struct ChangesView: View {
    let events: [CalendarEvent]

    var body: some View {
        NavigationStack {
            List {
                Section("Änderungen") {
                    if events.isEmpty {
                        Text("Keine Änderungen gespeichert")
                            .foregroundStyle(AppStyle.secondaryText)
                    } else {
                        ForEach(events, id: \.objectID) { event in
                            ChangeEventNavigationRow(event: event)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppStyle.background)
            .font(.interBody)
            .navigationTitle("Änderungen")
        }
    }
}

struct EventChangeDetail: Identifiable {
    let title: String
    let systemImage: String
    let oldValue: String
    let currentValue: String

    var id: String {
        title
    }
}

struct ChangeEventNavigationRow: View {
    let event: CalendarEvent

    var body: some View {
        NavigationLink {
            EventDetailView(event: event)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                EventRow(event: event, showsDate: true, showsTodayDetails: true)

                if event.isChangedEvent && event.changeDetails.isEmpty {
                    Text("Kein vorheriger Stand gespeichert")
                        .font(.interSubheadline)
                        .foregroundStyle(AppStyle.secondaryText)
                } else if !event.changeDetails.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(event.changeDetails) { detail in
                            ChangeDetailRow(detail: detail)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(event.subjectColor.opacity(0.16))
            )
            .overlay {
                if let stripeColor = event.unreadChangeColor {
                    StripedOverlay(color: stripeColor)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .overlay {
                if let borderStyle = event.categoryBorderStyle {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            borderStyle.color,
                            style: StrokeStyle(lineWidth: 2, dash: borderStyle.dash)
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if event.canBeMarkedAsRead {
                Button {
                    try? Shared.item.dataController.markAsRead(event)
                } label: {
                    Label("Abhaken", systemImage: "checkmark")
                }
                .tint(AppStyle.lime)
            }
        }
    }
}

struct ChangeDetailRow: View {
    let detail: EventChangeDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(detail.title, systemImage: detail.systemImage)
                .font(.interCaption.weight(.semibold))
                .foregroundStyle(AppStyle.blue)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(detail.oldValue)
                    .foregroundStyle(AppStyle.secondaryText)

                Image(systemName: "arrow.right")
                    .font(.interCaption.weight(.semibold))
                    .foregroundStyle(AppStyle.teal)

                Text(detail.currentValue)
                    .fontWeight(.semibold)
            }
            .font(.interSubheadline)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
        }
    }
}

struct ProfileView: View {
    @State private var firstName = "Max"
    @State private var lastName = "Mustermann"
    @State private var selectedClass = "Q1"

    private let availableClasses = [
        "EF",
        "Q1",
        "Q2",
        "11A",
        "11B",
        "12A",
        "12B"
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(AppStyle.brandGradient)
                                .frame(width: 86, height: 86)
                                .shadow(color: AppStyle.magenta.opacity(0.22), radius: 12, y: 6)

                            Text(initials)
                                .font(.interTitle.weight(.bold))
                                .foregroundStyle(.white)
                        }

                        VStack(spacing: 4) {
                            Text(fullName)
                                .font(.interTitle3)

                            Label(selectedClass, systemImage: "graduationcap")
                                .font(.interSubheadline)
                                .foregroundStyle(AppStyle.secondaryText)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                }
                .listRowBackground(AppStyle.surface)

                Section("Persönliche Daten") {
                    ProfileTextFieldRow(
                        title: "Vorname",
                        systemImage: "person",
                        text: $firstName
                    )

                    ProfileTextFieldRow(
                        title: "Nachname",
                        systemImage: "person.text.rectangle",
                        text: $lastName
                    )

                    Picker(selection: $selectedClass) {
                        ForEach(availableClasses, id: \.self) { className in
                            Text(className)
                                .tag(className)
                        }
                    } label: {
                        Label("Klasse", systemImage: "rectangle.stack.person.crop")
                    }
                    .pickerStyle(.menu)
                }

                Section("Konto") {
                    Label("AWS Cognito wird später angebunden", systemImage: "cloud")
                        .foregroundStyle(AppStyle.secondaryText)

                    Label("Datenquelle: ID-Token", systemImage: "key")
                        .foregroundStyle(AppStyle.secondaryText)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppStyle.background)
            .font(.interBody)
            .navigationTitle("Profil")
        }
    }

    private var fullName: String {
        let name = "\(firstName) \(lastName)"
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return name.isEmpty ? "Profil" : name
    }

    private var initials: String {
        let firstInitial = firstName.first.map(String.init) ?? ""
        let lastInitial = lastName.first.map(String.init) ?? ""
        let value = "\(firstInitial)\(lastInitial)"

        return value.isEmpty ? "?" : value.uppercased()
    }
}

struct ProfileTextFieldRow: View {
    let title: String
    let systemImage: String

    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Label(title, systemImage: systemImage)

            TextField(title, text: $text)
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.words)
        }
    }
}

enum ScheduleBlock: Int, CaseIterable, Identifiable {
    case first = 0
    case second = 1
    case third = 2
    case fourth = 3
    case fifth = 4

    var id: Self {
        self
    }

    var title: String {
        "\(startText)-\(endText)"
    }

    private var startText: String {
        switch self {
        case .first:
            return "08:00"
        case .second:
            return "09:50"
        case .third:
            return "11:30"
        case .fourth:
            return "13:45"
        case .fifth:
            return "15:30"
        }
    }

    private var endText: String {
        switch self {
        case .first:
            return "09:30"
        case .second:
            return "11:20"
        case .third:
            return "13:00"
        case .fourth:
            return "15:15"
        case .fifth:
            return "17:00"
        }
    }

    func contains(_ event: CalendarEvent) -> Bool {
        guard let start = event.start else {
            return false
        }

        let calendar = Foundation.Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: start)
        let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)

        return minutes >= startMinutes && minutes < endMinutes
    }

    private var startMinutes: Int {
        switch self {
        case .first:
            return 8 * 60
        case .second:
            return 9 * 60 + 50
        case .third:
            return 11 * 60 + 30
        case .fourth:
            return 13 * 60 + 45
        case .fifth:
            return 15 * 60 + 30
        }
    }

    private var endMinutes: Int {
        switch self {
        case .first:
            return 9 * 60 + 30
        case .second:
            return 11 * 60 + 20
        case .third:
            return 13 * 60
        case .fourth:
            return 15 * 60 + 15
        case .fifth:
            return 17 * 60
        }
    }
}

struct WeekScheduleView: View {
    let events: [CalendarEvent]

    @Binding var selectedWeekDate: Date

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DateNavigationHeader(
                    title: weekTitle,
                    previousAction: { moveWeek(by: -1) },
                    nextAction: { moveWeek(by: 1) }
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                ScrollView {
                    WeekScheduleGrid(
                        days: daysInSelectedWeek,
                        eventsForDay: events(on:)
                    )
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                    ScheduleLegendView()
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .padding(.bottom, 16)
                }
                .background(AppStyle.background)
            }
            .background(AppStyle.background)
            .font(.interBody)
            .navigationTitle("Wochenansicht")
        }
    }

    private var weekTitle: String {
        guard let firstDay = daysInSelectedWeek.first,
              let lastDay = daysInSelectedWeek.last else {
            return "Woche"
        }

        return "\(firstDay.formatted(date: .abbreviated, time: .omitted)) - \(lastDay.formatted(date: .abbreviated, time: .omitted))"
    }

    private var daysInSelectedWeek: [Date] {
        let calendar = Foundation.Calendar.current

        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedWeekDate) else {
            return []
        }

        return (0..<5).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: weekInterval.start)
        }
    }

    private func events(on date: Date) -> [CalendarEvent] {
        let calendar = Foundation.Calendar.current
        return events.filter { event in
            guard let start = event.start else {
                return false
            }

            return calendar.isDate(start, inSameDayAs: date)
        }
    }

    private func moveWeek(by value: Int) {
        selectedWeekDate = Foundation.Calendar.current.date(byAdding: .weekOfYear, value: value, to: selectedWeekDate) ?? selectedWeekDate
    }
}

struct WeekScheduleGrid: View {
    let days: [Date]
    let eventsForDay: (Date) -> [CalendarEvent]

    var body: some View {
        GeometryReader { geometry in
            let timeColumnWidth: CGFloat = 44
            let spacing: CGFloat = 6
            let contentWidth = geometry.size.width
            let cellSize = max(44, (contentWidth - timeColumnWidth - (spacing * 5)) / 5)

            VStack(alignment: .leading, spacing: spacing) {
                HStack(spacing: spacing) {
                    Color.clear
                        .frame(width: timeColumnWidth, height: 34)

                    ForEach(days, id: \.self) { day in
                        WeekDayHeader(day: day)
                            .frame(width: cellSize, height: 34)
                    }
                }

                ForEach(ScheduleBlock.allCases) { block in
                    HStack(alignment: .top, spacing: spacing) {
                        Text(block.title)
                            .font(.interCaption2.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(AppStyle.secondaryText)
                            .multilineTextAlignment(.trailing)
                            .frame(width: timeColumnWidth, height: cellSize, alignment: .topTrailing)
                            .padding(.top, 6)

                        ForEach(days, id: \.self) { day in
                            WeekBlockCell(
                                events: eventsForDay(day).filter { block.contains($0) }
                            )
                            .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
        }
        .frame(height: weekGridHeight)
    }

    private var weekGridHeight: CGFloat {
        let timeColumnWidth: CGFloat = 44
        let spacing: CGFloat = 6
        let screenWidth = UIScreen.main.bounds.width - 24
        let cellSize = max(44, (screenWidth - timeColumnWidth - (spacing * 5)) / 5)
        return 34 + spacing + (cellSize * CGFloat(ScheduleBlock.allCases.count)) + (spacing * CGFloat(ScheduleBlock.allCases.count - 1)) + 16
    }
}

struct WeekDayHeader: View {
    let day: Date

    var body: some View {
        VStack(spacing: 2) {
            Text(day.formatted(.dateTime.weekday(.abbreviated)))
                .font(.interCaption.weight(.semibold))
                .lineLimit(1)

            Text(day.formatted(.dateTime.day().month(.twoDigits)))
                .font(.interCaption2)
                .foregroundStyle(AppStyle.secondaryText)
                .lineLimit(1)
        }
    }
}

struct WeekBlockCell: View {
    let events: [CalendarEvent]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(AppStyle.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(AppStyle.blue.opacity(0.08), lineWidth: 1)
                }

            if !events.isEmpty {
                HStack(spacing: 3) {
                    if events.count == 1, let event = events.first {
                        WeekEventLink(event: event, showsIconOnly: false)
                    } else {
                        ForEach(events, id: \.objectID) { event in
                            WeekEventLink(event: event, showsIconOnly: true)
                        }
                    }
                }
                .padding(3)
            }
        }
    }
}

struct WeekEventLink: View {
    let event: CalendarEvent
    let showsIconOnly: Bool

    var body: some View {
        NavigationLink {
            EventDetailView(event: event)
        } label: {
            WeekEventTile(event: event, showsIconOnly: showsIconOnly)
        }
        .buttonStyle(.plain)
    }
}

struct WeekDayColumn: View {
    let day: Date
    let events: [CalendarEvent]

    var body: some View {
        VStack(spacing: 8) {
            Text(day.formatted(.dateTime.weekday(.abbreviated)))
                .font(.interCaption.weight(.semibold))
                .frame(maxWidth: .infinity)

            Text(day.formatted(.dateTime.day().month(.twoDigits)))
                .font(.interCaption2)
                .foregroundStyle(AppStyle.secondaryText)
                .frame(maxWidth: .infinity)

            if events.isEmpty {
                Text("-")
                    .foregroundStyle(AppStyle.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 34)
            } else {
                ForEach(events, id: \.objectID) { event in
                    NavigationLink {
                        EventDetailView(event: event)
                    } label: {
                        WeekEventTile(event: event)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(8)
        .background(AppStyle.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct WeekEventTile: View {
    let event: CalendarEvent
    var showsIconOnly = false

    var body: some View {
        Group {
            if showsIconOnly {
                Image(systemName: "rectangle.expand.vertical")
                    .font(.interCaption.weight(.semibold))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel(event.previewTitle)
            } else {
                Text(event.previewTitle)
                    .font(.interCaption.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
            .frame(maxWidth: .infinity, minHeight: 34)
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(event.subjectColor.opacity(0.18))
            )
            .foregroundStyle(AppStyle.primaryText)
            .overlay {
                if let stripeColor = event.unreadChangeColor {
                    StripedOverlay(color: stripeColor)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .overlay {
                if let borderStyle = event.categoryBorderStyle {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            borderStyle.color,
                            style: StrokeStyle(lineWidth: 1.5, dash: borderStyle.dash)
                        )
                }
            }
    }
}

struct ScheduleLegendView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Legende")
                .font(.interCaption.weight(.semibold))
                .foregroundStyle(AppStyle.blue)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], alignment: .leading, spacing: 8) {
                LegendItem(title: "Klausur") {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.clear)
                        .overlay {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(AppStyle.magenta, lineWidth: 2)
                        }
                }

                LegendItem(title: "Selbstlernzeit") {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.clear)
                        .overlay {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(AppStyle.blue, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        }
                }

                LegendItem(title: "Neu") {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppStyle.lime.opacity(0.12))
                        .overlay {
                            StripedOverlay(color: AppStyle.lime)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                }

                LegendItem(title: "Geändert") {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppStyle.orange.opacity(0.12))
                        .overlay {
                            StripedOverlay(color: AppStyle.orange)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                }

                LegendItem(title: "Gelöscht") {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppStyle.magenta.opacity(0.12))
                        .overlay {
                            StripedOverlay(color: AppStyle.magenta)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                }
            }
        }
        .padding(10)
        .background(AppStyle.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct LegendItem<Symbol: View>: View {
    let title: String
    @ViewBuilder let symbol: () -> Symbol

    var body: some View {
        HStack(spacing: 8) {
            symbol()
                .frame(width: 26, height: 18)

            Text(title)
                .font(.interCaption)
                .lineLimit(1)
        }
    }
}

struct DateNavigationHeader: View {
    let title: String
    let previousAction: () -> Void
    let nextAction: () -> Void

    var body: some View {
        HStack {
            Button {
                previousAction()
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(AppStyle.blue)
                    .frame(width: 44, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Zurück")

            Spacer()

            Text(title)
                .font(.interHeadline)
                .foregroundStyle(AppStyle.primaryText)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                nextAction()
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppStyle.blue)
                    .frame(width: 44, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Weiter")
        }
    }
}

struct EventNavigationRow: View {
    let event: CalendarEvent
    var showsDate = false
    var showsTodayDetails = false
    var addsVerticalSpacing = false

    var body: some View {
        NavigationLink {
            EventDetailView(event: event)
        } label: {
            EventRow(event: event, showsDate: showsDate, showsTodayDetails: showsTodayDetails)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(event.subjectColor.opacity(0.16))
            )
            .overlay {
                if let stripeColor = event.unreadChangeColor {
                    StripedOverlay(color: stripeColor)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .overlay {
                if let borderStyle = event.categoryBorderStyle {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            borderStyle.color,
                            style: StrokeStyle(lineWidth: 2, dash: borderStyle.dash)
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .listRowInsets(
            EdgeInsets(
                top: addsVerticalSpacing ? 6 : 0,
                leading: 16,
                bottom: addsVerticalSpacing ? 6 : 0,
                trailing: 16
            )
        )
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if event.canBeMarkedAsRead {
                Button {
                    try? Shared.item.dataController.markAsRead(event)
                } label: {
                    Label("Abhaken", systemImage: "checkmark")
                }
                .tint(AppStyle.lime)
            }
        }
    }
}

struct StripedOverlay: View {
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let spacing: CGFloat = 12
                let size = geometry.size
                var x = -size.height

                while x < size.width {
                    path.move(to: CGPoint(x: x, y: size.height))
                    path.addLine(to: CGPoint(x: x + size.height, y: 0))
                    x += spacing
                }
            }
            .stroke(color.opacity(0.45), lineWidth: 4)
        }
        .allowsHitTesting(false)
    }
}

struct EventRow: View {
    let event: CalendarEvent
    var showsDate = false
    var showsTodayDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.previewTitle)
                .font(.interHeadline)
                .foregroundStyle(AppStyle.primaryText)

            if showsDate, let start = event.start {
                Label(start.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    .font(.interSubheadline)
                    .foregroundStyle(AppStyle.secondaryText)
            }

            if showsTodayDetails {
                if let timeText = event.timeText {
                    Label(timeText, systemImage: "clock")
                        .font(.interSubheadline)
                        .foregroundStyle(AppStyle.secondaryText)
                }

                if let lecturerText = event.lecturerText {
                    Label(lecturerText, systemImage: "person")
                        .font(.interSubheadline)
                        .foregroundStyle(AppStyle.secondaryText)
                }
            }

            if let location = event.formattedLocation {
                Label(location, systemImage: "mappin")
                    .font(.interSubheadline)
                    .foregroundStyle(AppStyle.secondaryText)
            }
        }
    }
}

extension CalendarEvent {
    var previewTitle: String {
        if isBibEvent,
           let summary = cleanSummary,
           !summary.isEmpty {
            return summary
        }

        return subjectCode ?? label ?? "Termin"
    }

    var subjectCode: String? {
        firstThreeCharacterCode(from: summary)
    }

    var subjectColor: Color {
        AppStyle.subjectColor(for: subjectCode)
    }

    var categoryBorderStyle: (color: Color, dash: [CGFloat])? {
        let categoryText = category?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch categoryText {
        case "selbstlernzeit":
            return (AppStyle.blue, [6, 4])
        case "klausur":
            return (AppStyle.magenta, [])
        default:
            return nil
        }
    }

    var isExam: Bool {
        category?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() == "klausur"
    }

    var isBibEvent: Bool {
        category?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() == "bib-events"
    }

    var formattedLocation: String? {
        formattedLocationText(from: location)
    }

    var isVisibleInSchedule: Bool {
        !(normalizedLabel == "geloescht" && read)
    }

    var canBeMarkedAsRead: Bool {
        !read && normalizedLabel != nil
    }

    var hasChangeLabel: Bool {
        normalizedLabel != nil
    }

    var isChangedEvent: Bool {
        normalizedLabel == "geaendert"
    }

    var unreadChangeColor: Color? {
        guard !read else {
            return nil
        }

        switch normalizedLabel {
        case "neu":
            return AppStyle.lime
        case "geaendert":
            return AppStyle.orange
        case "geloescht":
            return AppStyle.magenta
        default:
            return nil
        }
    }

    var timeText: String? {
        switch (start, end) {
        case let (start?, end?):
            return "\(start.formatted(date: .omitted, time: .shortened)) - \(end.formatted(date: .omitted, time: .shortened))"
        case let (start?, nil):
            return start.formatted(date: .omitted, time: .shortened)
        case let (nil, end?):
            return end.formatted(date: .omitted, time: .shortened)
        case (nil, nil):
            return nil
        }
    }

    var changeDetails: [EventChangeDetail] {
        guard isChangedEvent, let originalEvent else {
            return []
        }

        var details: [EventChangeDetail] = []

        appendChange(
            title: "Raum",
            systemImage: "mappin",
            oldValue: originalEvent.formattedLocation,
            currentValue: formattedLocation,
            to: &details
        )
        appendChange(
            title: "Datum",
            systemImage: "calendar",
            oldValue: originalEvent.changeDateText,
            currentValue: changeDateText,
            to: &details
        )
        appendChange(
            title: "Zeit",
            systemImage: "clock",
            oldValue: originalEvent.changeTimeText,
            currentValue: changeTimeText,
            to: &details
        )
        appendChange(
            title: "Beschreibung",
            systemImage: "doc.text",
            oldValue: nonEmpty(descriptions: originalEvent.descriptions),
            currentValue: nonEmpty(descriptions: descriptions),
            to: &details
        )

        return details
    }

    private var changeTimeText: String? {
        formattedTimeText(start: start, end: end, showsDate: false)
    }

    private var changeDateText: String? {
        formattedDateText(start: start, end: end)
    }

    var lecturerText: String? {
        guard let summary else {
            return nil
        }

        let tokens = summary
            .uppercased()
            .split(separator: " ")
            .map { token in
                token.trimmingCharacters(in: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-")).inverted)
            }
            .filter { !$0.isEmpty }

        guard let subjectIndex = tokens.firstIndex(where: { firstThreeCharacterCode(from: $0) == subjectCode }),
              tokens.indices.contains(subjectIndex + 1) else {
            return nil
        }

        let lecturer = tokens[subjectIndex + 1]

        guard !lecturer.hasPrefix("P-"),
              lecturer.count == 3,
              lecturer.allSatisfy({ $0.isLetter }) else {
            return nil
        }

        return lecturer
    }

    private var cleanSummary: String? {
        guard let summary = summary?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !summary.isEmpty else {
            return nil
        }

        return summary.hasPrefix("* ") ? String(summary.dropFirst(2)) : summary
    }

    private var normalizedLabel: String? {
        guard let label = label?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current),
              !label.isEmpty else {
            return nil
        }

        switch label {
        case "neu":
            return "neu"
        case "geaendert", "geandert":
            return "geaendert"
        case "geloescht", "geloscht":
            return "geloescht"
        default:
            return nil
        }
    }

    fileprivate func firstThreeCharacterCode(from value: String?) -> String? {
        guard let value else {
            return nil
        }

        let cleanedValue = value.hasPrefix("* ") ? String(value.dropFirst(2)) : value
        let code = String(
            cleanedValue
                .uppercased()
                .filter { $0.isLetter || $0.isNumber }
                .prefix(3)
        )

        guard code.count == 3 else {
            return nil
        }

        return code
    }
}

extension OriginalEvent {
    var formattedLocation: String? {
        formattedLocationText(from: location)
    }

    var changeTimeText: String? {
        formattedTimeText(start: start, end: end, showsDate: false)
    }

    var changeDateText: String? {
        formattedDateText(start: start, end: end)
    }

}

private func appendChange(
    title: String,
    systemImage: String,
    oldValue: String?,
    currentValue: String?,
    to details: inout [EventChangeDetail]
) {
    guard let oldValue = normalizedDisplayValue(oldValue),
          let currentValue = normalizedDisplayValue(currentValue),
          oldValue != currentValue else {
        return
    }

    details.append(
        EventChangeDetail(
            title: title,
            systemImage: systemImage,
            oldValue: oldValue,
            currentValue: currentValue
        )
    )
}

private func formattedLocationText(from value: String?) -> String? {
    guard let location = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          !location.isEmpty else {
        return nil
    }

    let uppercasedLocation = location.uppercased()
    let characters = Array(uppercasedLocation)

    if characters.count >= 2,
       characters[characters.count - 2] == ".",
       characters[characters.count - 1].isLetter {
        return "\(characters[characters.count - 1])-Pool"
    }

    let digits = uppercasedLocation.filter { $0.isNumber }
    if digits.count >= 3 {
        let lastThreeDigits = String(digits.suffix(3))
        if lastThreeDigits.first == "2" {
            return "Raum \(lastThreeDigits)"
        }
    }

    return location
}

private func formattedTimeText(start: Date?, end: Date?, showsDate: Bool) -> String? {
    let dateStyle: Date.FormatStyle.DateStyle = showsDate ? .abbreviated : .omitted

    switch (start, end) {
    case let (start?, end?):
        return "\(start.formatted(date: dateStyle, time: .shortened)) - \(end.formatted(date: .omitted, time: .shortened))"
    case let (start?, nil):
        return start.formatted(date: dateStyle, time: .shortened)
    case let (nil, end?):
        return end.formatted(date: dateStyle, time: .shortened)
    case (nil, nil):
        return nil
    }
}

private func formattedDateText(start: Date?, end: Date?) -> String? {
    guard let date = start ?? end else {
        return nil
    }

    return date.formatted(date: .abbreviated, time: .omitted)
}

private func nonEmpty(descriptions value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          !value.isEmpty else {
        return nil
    }

    return value
}

private func normalizedDisplayValue(_ value: String?) -> String? {
    guard let value = nonEmpty(descriptions: value) else {
        return nil
    }

    return value
        .components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
}

private func changedDetailText(oldValue: String?, currentValue: String?) -> String? {
    guard let oldValue = normalizedDisplayValue(oldValue),
          let currentValue = normalizedDisplayValue(currentValue),
          oldValue != currentValue else {
        return nil
    }

    return "\(oldValue) -> \(currentValue)"
}

struct EventDetailView: View {
    let event: CalendarEvent

    var body: some View {
        List {
            Section("Aktueller Stand") {
                DetailRow(title: "Datum", value: detailDateText)
                DetailRow(title: "Zeit", value: detailTimeText)
                DetailRow(title: "Raum", value: detailLocationText)
                DetailRow(title: "Kategorie", value: event.category)
                DetailRow(title: "Dozent", value: event.lecturerText)
                DetailRow(title: "Label", value: event.label)
            }

            if let descriptions = nonEmpty(event.descriptions) {
                Section("Beschreibung") {
                    Text(descriptions)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppStyle.background)
        .font(.interBody)
        .navigationTitle(event.summary ?? event.label ?? "Termin")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var detailTimeText: String? {
        guard event.isChangedEvent else {
            return currentTimeText
        }

        return changedDetailText(
            oldValue: event.originalEvent?.changeTimeText,
            currentValue: formattedTimeText(start: event.start, end: event.end, showsDate: false)
        ) ?? currentTimeText
    }

    private var detailDateText: String? {
        guard event.isChangedEvent else {
            return currentDateText
        }

        return changedDetailText(
            oldValue: event.originalEvent?.changeDateText,
            currentValue: formattedDateText(start: event.start, end: event.end)
        ) ?? currentDateText
    }

    private var detailLocationText: String? {
        guard event.isChangedEvent else {
            return event.formattedLocation
        }

        return changedDetailText(
            oldValue: event.originalEvent?.formattedLocation,
            currentValue: event.formattedLocation
        ) ?? event.formattedLocation
    }

    private var currentDateText: String? {
        formattedDateText(start: event.start, end: event.end)
    }

    private var currentTimeText: String? {
        formattedTimeText(start: event.start, end: event.end, showsDate: false)
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }

        return value
    }
}

struct DetailRow: View {
    let title: String
    let value: String?

    var body: some View {
        if let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
            HStack {
                Text(title)
                    .foregroundStyle(AppStyle.secondaryText)
                Spacer()
                Text(value)
                    .foregroundStyle(AppStyle.primaryText)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}

#Preview {
    let dataController = DataController(inMemory: true)

    ContentView()
        .environment(\.managedObjectContext, dataController.viewContext)
}

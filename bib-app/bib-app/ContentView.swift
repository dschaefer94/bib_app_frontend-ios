import CoreData
import SwiftUI

struct ContentView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Calendar.timestamp, ascending: false)],
        animation: .default
    )
    private var calendars: FetchedResults<Calendar>

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedTab: CalendarTab = .today
    @State private var selectedDayDate = Date()
    @State private var selectedWeekDate = Date()

    var body: some View {
        VStack(spacing: 0) {
            selectedView
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack(spacing: 0) {
                BottomMenuButton(
                    tab: .week,
                    isSelected: selectedTab == .week,
                    action: { select(.week) }
                )
                BottomMenuButton(
                    tab: .schedule,
                    isSelected: selectedTab == .schedule,
                    action: { select(.schedule) }
                )
                BottomMenuButton(
                    tab: .today,
                    isSelected: selectedTab == .today,
                    action: { select(.today) }
                )

                Spacer()
                    .frame(maxWidth: .infinity)

                Spacer()
                    .frame(maxWidth: .infinity)
            }
            .padding(.top, 8)
            .padding(.bottom, 6)
            .background(.bar)
        }
    }

    @ViewBuilder
    private var selectedView: some View {
        switch selectedTab {
        case .week:
            WeekScheduleView(events: allEvents, selectedWeekDate: $selectedWeekDate)
        case .schedule:
            DayScheduleView(events: allEvents, selectedDate: $selectedDayDate)
        case .today:
            TodayView(
                nextEvent: nextEvent,
                laterTodayEvents: laterTodayEvents,
                isLoading: isLoading,
                errorMessage: errorMessage,
                importCalendar: importCalendar
            )
        }
    }

    private func select(_ tab: CalendarTab) {
        selectedTab = tab

        switch tab {
        case .week:
            selectedWeekDate = Date()
        case .schedule:
            selectedDayDate = Date()
        case .today:
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
        calendars
            .flatMap { calendar in
                calendar.events?.allObjects as? [CalendarEvent] ?? []
            }
            .filter(\.isVisibleInSchedule)
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
}

enum CalendarTab {
    case week
    case schedule
    case today

    var title: String {
        switch self {
        case .week:
            return "Woche"
        case .schedule:
            return "Stundenplan"
        case .today:
            return "Heute"
        }
    }

    var systemImage: String {
        switch self {
        case .week:
            return "calendar"
        case .schedule:
            return "list.bullet"
        case .today:
            return "house"
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
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .frame(maxWidth: .infinity)
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
                            .foregroundStyle(.red)
                    }
                }

                Section("Nächstes Fach") {
                    if let event = nextEvent {
                        EventNavigationRow(event: event, showsTodayDetails: true, addsVerticalSpacing: true)
                    } else {
                        Text("Kein kommender Kurs gespeichert")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Kurse danach") {
                    if laterTodayEvents.isEmpty {
                        Text("Keine weiteren Kurse für heute gespeichert")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(laterTodayEvents, id: \.objectID) { event in
                            EventNavigationRow(event: event, addsVerticalSpacing: true)
                        }
                    }
                }
            }
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

struct DayScheduleView: View {
    let events: [CalendarEvent]

    @Binding var selectedDate: Date

    var body: some View {
        NavigationStack {
            List {
                DateNavigationBar(
                    title: selectedDate.formatted(date: .complete, time: .omitted),
                    previousAction: { moveDay(by: -1) },
                    nextAction: { moveDay(by: 1) }
                )

                Section("Kurse") {
                    if eventsForSelectedDate.isEmpty {
                        Text("Keine Kurse für diesen Tag gespeichert")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(visibleScheduleBlocks) { block in
                            DayScheduleBlockRow(
                                block: block,
                                events: eventsForSelectedDate.filter { block.contains($0) }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Stundenplan")
        }
    }

    private var eventsForSelectedDate: [CalendarEvent] {
        let calendar = Foundation.Calendar.current
        return events.filter { event in
            guard let start = event.start else {
                return false
            }

            return calendar.isDate(start, inSameDayAs: selectedDate)
        }
    }

    private var visibleScheduleBlocks: [ScheduleBlock] {
        guard let lastOccupiedBlock = ScheduleBlock.allCases.last(where: { block in
            eventsForSelectedDate.contains { block.contains($0) }
        }) else {
            return []
        }

        return ScheduleBlock.allCases.filter { block in
            block.rawValue <= lastOccupiedBlock.rawValue
        }
    }

    private func moveDay(by value: Int) {
        selectedDate = Foundation.Calendar.current.date(byAdding: .day, value: value, to: selectedDate) ?? selectedDate
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

struct DayScheduleBlockRow: View {
    let block: ScheduleBlock
    let events: [CalendarEvent]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(block.title)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 86, alignment: .leading)
                .padding(.top, 14)

            VStack(spacing: 12) {
                if events.isEmpty {
                    Text("Frei")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 14)
                } else {
                    ForEach(events, id: \.objectID) { event in
                        EventNavigationRow(event: event)
                    }
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowSeparator(.hidden)
    }
}

struct WeekScheduleView: View {
    let events: [CalendarEvent]

    @Binding var selectedWeekDate: Date

    var body: some View {
        NavigationStack {
            List {
                DateNavigationBar(
                    title: weekTitle,
                    previousAction: { moveWeek(by: -1) },
                    nextAction: { moveWeek(by: 1) }
                )

                ForEach(daysInSelectedWeek, id: \.self) { day in
                    Section(day.formatted(date: .complete, time: .omitted)) {
                        let dayEvents = events(on: day)

                        if dayEvents.isEmpty {
                            Text("Keine Kurse")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(dayEvents, id: \.objectID) { event in
                                EventNavigationRow(event: event)
                            }
                        }
                    }
                }
            }
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

        return (0..<7).compactMap { offset in
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

struct DateNavigationBar: View {
    let title: String
    let previousAction: () -> Void
    let nextAction: () -> Void

    var body: some View {
        Section {
            HStack {
                Button {
                    previousAction()
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Zurück")

                Spacer()

                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Spacer()

                Button {
                    nextAction()
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 44, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Weiter")
            }
        }
    }
}

struct EventNavigationRow: View {
    let event: CalendarEvent
    var showsTodayDetails = false
    var addsVerticalSpacing = false

    var body: some View {
        NavigationLink {
            EventDetailView(event: event)
        } label: {
            EventRow(event: event, showsTodayDetails: showsTodayDetails)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(event.subjectColor.opacity(0.28))
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
                .tint(.green)
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
    var showsTodayDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.subjectCode ?? event.label ?? "Termin")
                .font(.headline)

            if showsTodayDetails {
                if let timeText = event.timeText {
                    Label(timeText, systemImage: "clock")
                        .font(.subheadline)
                }

                if let lecturerText = event.lecturerText {
                    Label(lecturerText, systemImage: "person")
                        .font(.subheadline)
                }
            }

            if let location = event.formattedLocation {
                Label(location, systemImage: "mappin")
                    .font(.subheadline)
            }
        }
    }
}

extension CalendarEvent {
    var subjectCode: String? {
        firstThreeCharacterCode(from: summary)
    }

    var subjectColor: Color {
        guard let subjectCode else {
            return Color(.secondarySystemGroupedBackground)
        }

        let values = subjectCode.map { characterValue($0) }
        guard values.count == 3 else {
            return Color(.secondarySystemGroupedBackground)
        }

        return Color(
            red: Double(values[0]) / 35.0,
            green: Double(values[1]) / 35.0,
            blue: Double(values[2]) / 35.0
        )
    }

    var categoryBorderStyle: (color: Color, dash: [CGFloat])? {
        let categoryText = category?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch categoryText {
        case "selbstlernzeit":
            return (.black, [6, 4])
        case "klausur":
            return (.red, [])
        default:
            return nil
        }
    }

    var formattedLocation: String? {
        guard let location = location?.trimmingCharacters(in: .whitespacesAndNewlines),
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

    var isVisibleInSchedule: Bool {
        !(normalizedLabel == "geloescht" && read)
    }

    var canBeMarkedAsRead: Bool {
        !read && normalizedLabel != nil
    }

    var unreadChangeColor: Color? {
        guard !read else {
            return nil
        }

        switch normalizedLabel {
        case "neu":
            return .green
        case "geaendert":
            return .yellow
        case "geloescht":
            return .red
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
        case "geaendert", "gelandert":
            return "geaendert"
        case "geloescht":
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

    private func characterValue(_ character: Character) -> Int {
        let scalars = String(character).unicodeScalars
        guard let value = scalars.first?.value else {
            return 0
        }

        switch value {
        case 48...57:
            return Int(value - 48)
        case 65...90:
            return Int(value - 55)
        default:
            return 0
        }
    }
}

struct EventDetailView: View {
    let event: CalendarEvent

    var body: some View {
        List {
            Section {
                DetailRow(title: "Zeit", value: timeText)
                DetailRow(title: "Raum", value: event.formattedLocation)
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
        .navigationTitle(event.summary ?? event.label ?? "Termin")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var timeText: String? {
        switch (event.start, event.end) {
        case let (start?, end?):
            return "\(start.formatted(date: .abbreviated, time: .shortened)) - \(end.formatted(date: .omitted, time: .shortened))"
        case let (start?, nil):
            return start.formatted(date: .abbreviated, time: .shortened)
        case let (nil, end?):
            return end.formatted(date: .abbreviated, time: .shortened)
        case (nil, nil):
            return nil
        }
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
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
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

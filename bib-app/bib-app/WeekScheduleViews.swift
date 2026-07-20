import SwiftUI
// wichtigste View: Wochenübersicht der Termine, bib-konform
// letztendlich ist das Grid nichts anderes als verschachtelte Listen
// Termine werden farblich und rahmentechnisch entsprechend ihrer Art markiert
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
        "\(startText)\n- \(endText)"
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
// Ferien sollen nur den ersten Block repräsentativ markieren
    func contains(_ event: CalendarEvent) -> Bool {
        if event.isHolidayEvent {
            return self == .first
        }

        guard let start = event.start else {
            return false
        }

        let calendar = Foundation.Calendar.current
        let startMinutes = minutesSinceStartOfDay(for: start, calendar: calendar)

        guard let end = event.end, end > start else {
            return startMinutes >= self.startMinutes && startMinutes < self.endMinutes
        }

        var endMinutes = minutesSinceStartOfDay(for: end, calendar: calendar)
        if endMinutes <= startMinutes {
            endMinutes += 24 * 60
        }

        return startMinutes < self.endMinutes && endMinutes > self.startMinutes
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

    private func minutesSinceStartOfDay(for date: Date, calendar: Foundation.Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return ((components.hour ?? 0) * 60) + (components.minute ?? 0)
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
        guard let dayInterval = calendar.dateInterval(of: .day, for: date) else {
            return []
        }

        return events.filter { event in
            guard let start = event.start else {
                return false
            }

            let end = event.end ?? start.addingTimeInterval(60)
            return start < dayInterval.end && end > dayInterval.start
        }
    }
// sieht mit "by"-Aufruf hübscher aus
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
            Text(weekdayText)
                .font(.interCaption.weight(.semibold))
                .lineLimit(1)

            Text(day.formatted(.dateTime.day().month(.twoDigits)))
                .font(.interCaption2)
                .foregroundStyle(AppStyle.secondaryText)
                .lineLimit(1)
        }
    }

    private var weekdayText: String {
        wochentagKuerzel(for: day)
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
            Text(wochentagKuerzel(for: day))
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
        VStack(alignment: .leading, spacing: 10) {
            Text("Legende")
                .font(.interCaption.weight(.semibold))
                .foregroundStyle(AppStyle.blue)

            HStack(alignment: .top, spacing: 14) {
                LegendColumn(title: "Kategorie") {
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

                    LegendItem(title: "Ferien") {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.clear)
                            .overlay {
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(AppStyle.lime, lineWidth: 2)
                            }
                    }

                    LegendItem(title: "bib-Events") {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.clear)
                            .overlay {
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(AppStyle.yellow, lineWidth: 2)
                            }
                        }
                }

                LegendColumn(title: "Label") {
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
        }
        .padding(10)
        .background(AppStyle.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct LegendColumn<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.interCaption.weight(.semibold))
                .foregroundStyle(AppStyle.secondaryText)

            VStack(alignment: .leading, spacing: 7) {
                content()
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
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
// falls auf einmal Sonntagstermine relevant sind als Platzhalter
// vllt. später enablebar
private func wochentagKuerzel(for date: Date) -> String {
    let weekday = Foundation.Calendar.current.component(.weekday, from: date)
    switch weekday {
    case 2:
        return "Mo"
    case 3:
        return "Di"
    case 4:
        return "Mi"
    case 5:
        return "Do"
    case 6:
        return "Fr"
    case 7:
        return "Sa"
    case 1:
        return "So"
    default:
        return date.formatted(.dateTime.weekday(.abbreviated))
    }
}

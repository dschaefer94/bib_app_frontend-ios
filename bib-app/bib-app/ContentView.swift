
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
                calendarTimestamp: latestCalendarTimestamp,
                currentEvent: currentEvent,
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
                errorMessage = "Du scheinst offline zu sein."
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

    private var latestCalendarTimestamp: Date? {
        calendars.first?.timestamp
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

    private var currentEvent: CalendarEvent? {
        let now = Date()
        return todaysEvents.first { event in
            guard let start = event.start,
                  let end = event.end else {
                return false
            }

            return start <= now && now < end
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

#Preview {
    let dataController = DataController(inMemory: true)

    ContentView()
        .environment(\.managedObjectContext, dataController.viewContext)
}

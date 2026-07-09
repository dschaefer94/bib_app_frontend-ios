import SwiftUI

struct TodayView: View {
    let calendarTimestamp: Date?
    let currentEvent: CalendarEvent?
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

                Section("Aktuelles Fach") {
                    if let event = currentEvent {
                        EventNavigationRow(event: event, showsTodayDetails: true, addsVerticalSpacing: true)
                    } else {
                        Text("Kein aktueller Kurs gespeichert")
                            .foregroundStyle(AppStyle.secondaryText)
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

                if let calendarTimestamp {
                    Text(timestampText(for: calendarTimestamp))
                        .font(.interCaption2)
                        .foregroundStyle(AppStyle.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 10, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
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

    private func timestampText(for date: Date) -> String {
        "Stand: \(date.formatted(date: .abbreviated, time: .shortened))"
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

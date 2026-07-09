import SwiftUI

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


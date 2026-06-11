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

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        importCalendar()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Kalender laden", systemImage: "arrow.down.circle")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isLoading)

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("JSON-Import")
                }

                ForEach(calendars) { calendar in
                    Section {
                        let events = sortedEvents(for: calendar)

                        if events.isEmpty {
                            Text("Keine Termine gespeichert")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(events, id: \.objectID) { event in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.summary ?? event.label ?? "Termin")
                                        .font(.headline)

                                    if let start = event.start {
                                        Text(start.formatted(date: .abbreviated, time: .shortened))
                                            .foregroundStyle(.secondary)
                                    }

                                    if let location = event.location, !location.isEmpty {
                                        Label(location, systemImage: "mappin")
                                            .font(.subheadline)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    } header: {
                        Text(calendar.timestamp?.formatted(date: .abbreviated, time: .shortened) ?? "Kalender")
                    }
                }
            }
            .navigationTitle("Kalender")
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

    private func sortedEvents(for calendar: Calendar) -> [CalendarEvent] {
        let events = calendar.events?.allObjects as? [CalendarEvent] ?? []
        return events.sorted {
            ($0.start ?? .distantFuture) < ($1.start ?? .distantFuture)
        }
    }
}

#Preview {
    let dataController = DataController(inMemory: true)

    ContentView()
        .environment(\.managedObjectContext, dataController.viewContext)
}

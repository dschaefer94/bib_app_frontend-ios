import CoreData
import Foundation

struct CalendarResponse: Decodable, Sendable {
    let timestamp: Date
    let events: [CalendarEventResponse]
}

struct CalendarEventResponse: Decodable, Sendable {
    let category: String?
    let description: String?
    let end: Date?
    let id: UUID?
    let label: String?
    let location: String?
    let read: Bool?
    let start: Date?
    let summary: String?

    private enum CodingKeys: String, CodingKey {
        case category
        case description
        case end
        case id
        case label
        case location
        case read
        case start
        case summary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        end = try container.decodeIfPresent(Date.self, forKey: .end)
        id = try container.decodeIfPresent(UUID.self, forKey: .id)
        label = try container.decodeIfPresent(String.self, forKey: .label)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        read = try container.decodeIfPresent(Bool.self, forKey: .read)
        start = try container.decodeIfPresent(Date.self, forKey: .start)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
    }
}

enum CalendarImportError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)
    case invalidDate(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Die URL hat keine gültige HTTP-Antwort geliefert."
        case .httpStatus(let status):
            return "Der Server antwortete mit HTTP-Status \(status)."
        case .invalidDate(let value):
            return "Das Datum \"\(value)\" konnte nicht gelesen werden."
        }
    }
}

@MainActor
final class DataController {
    private static let calendarURL = URL(string: "https://testapi.pbd2h24asc.web.bib.de")!

    let container: NSPersistentContainer

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Model")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Core Data konnte nicht geladen werden: \(error.localizedDescription)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    @discardableResult
    func loadCalendar() async throws -> Calendar {
        let (data, response) = try await URLSession.shared.data(from: Self.calendarURL)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CalendarImportError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw CalendarImportError.httpStatus(httpResponse.statusCode)
        }

        let responseCalendar = try Self.makeDecoder().decode(CalendarResponse.self, from: data)
        return try store(responseCalendar)
    }

    func fetchCalendars() throws -> [Calendar] {
        let request: NSFetchRequest<Calendar> = Calendar.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Calendar.timestamp, ascending: false)]
        request.returnsObjectsAsFaults = false
        return try viewContext.fetch(request)
    }

    func save() throws {
        guard viewContext.hasChanges else {
            return
        }

        try viewContext.save()
    }

    private func store(_ responseCalendar: CalendarResponse) throws -> Calendar {
        try deleteStoredCalendarData()

        let calendar = Calendar(context: viewContext)
        calendar.timestamp = responseCalendar.timestamp

        for responseEvent in responseCalendar.events {
            let event = CalendarEvent(context: viewContext)
            event.category = responseEvent.category
            event.descriptions = responseEvent.description
            event.end = responseEvent.end
            event.id = responseEvent.id ?? UUID()
            event.label = responseEvent.label
            event.location = responseEvent.location
            event.read = responseEvent.read ?? responseEvent.labelIsEmpty
            event.start = responseEvent.start
            event.summary = responseEvent.summary
            event.calendar = calendar
        }

        try save()
        return calendar
    }

    func markAsRead(_ event: CalendarEvent) throws {
        event.read = true
        try save()
    }

    private func deleteStoredCalendarData() throws {
        let eventRequest: NSFetchRequest<CalendarEvent> = CalendarEvent.fetchRequest()
        let events = try viewContext.fetch(eventRequest)
        events.forEach(viewContext.delete)

        let originalEventRequest: NSFetchRequest<OriginalEvent> = OriginalEvent.fetchRequest()
        let originalEvents = try viewContext.fetch(originalEventRequest)
        originalEvents.forEach(viewContext.delete)

        let calendarRequest: NSFetchRequest<Calendar> = Calendar.fetchRequest()
        let calendars = try viewContext.fetch(calendarRequest)
        calendars.forEach(viewContext.delete)
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()

            if let seconds = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: seconds)
            }

            let value = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            if let date = formatter.date(from: value) {
                return date
            }

            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: value) {
                return date
            }

            throw CalendarImportError.invalidDate(value)
        }
        return decoder
    }
}

private extension CalendarEventResponse {
    var labelIsEmpty: Bool {
        guard let label = label?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return true
        }

        return label.isEmpty
    }
}

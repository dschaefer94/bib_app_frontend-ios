//
//  CalendarEvent+CoreDataProperties.swift
//  bib-app
//
//  Created by Daniel Schäfer / PBD2H24A on 11.06.26.
//
//

public import Foundation
public import CoreData


public typealias CalendarEventCoreDataPropertiesSet = NSSet

extension CalendarEvent {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CalendarEvent> {
        return NSFetchRequest<CalendarEvent>(entityName: "CalendarEvent")
    }

    @NSManaged public var category: String?
    @NSManaged public var descriptions: String?
    @NSManaged public var end: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var label: String?
    @NSManaged public var location: String?
    @NSManaged public var start: Date?
    @NSManaged public var summary: String?
    @NSManaged public var calendar: Calendar?
    @NSManaged public var originalEvent: OriginalEvent?

}

extension CalendarEvent : Identifiable {

}

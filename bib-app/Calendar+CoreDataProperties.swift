//
//  Calendar+CoreDataProperties.swift
//  bib-app
//
//  Created by Daniel Schäfer / PBD2H24A on 11.06.26.
//
//

public import Foundation
public import CoreData


public typealias CalendarCoreDataPropertiesSet = NSSet

extension Calendar {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Calendar> {
        return NSFetchRequest<Calendar>(entityName: "Calendar")
    }

    @NSManaged public var timestamp: Date?
    @NSManaged public var events: NSSet?

}

// MARK: Generated accessors for events
extension Calendar {

    @objc(addEventsObject:)
    @NSManaged public func addToEvents(_ value: CalendarEvent)

    @objc(removeEventsObject:)
    @NSManaged public func removeFromEvents(_ value: CalendarEvent)

    @objc(addEvents:)
    @NSManaged public func addToEvents(_ values: NSSet)

    @objc(removeEvents:)
    @NSManaged public func removeFromEvents(_ values: NSSet)

}

extension Calendar : Identifiable {

}

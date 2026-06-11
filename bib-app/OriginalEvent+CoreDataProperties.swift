//
//  OriginalEvent+CoreDataProperties.swift
//  bib-app
//
//  Created by Daniel Schäfer / PBD2H24A on 11.06.26.
//
//

import Foundation
import CoreData


public typealias OriginalEventCoreDataPropertiesSet = NSSet

extension OriginalEvent {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<OriginalEvent> {
        return NSFetchRequest<OriginalEvent>(entityName: "OriginalEvent")
    }

    @NSManaged public var descriptions: String?
    @NSManaged public var end: Date?
    @NSManaged public var location: String?
    @NSManaged public var start: Date?
    @NSManaged public var summary: String?
    @NSManaged public var parentEvent: CalendarEvent?

}

extension OriginalEvent : Identifiable {

}

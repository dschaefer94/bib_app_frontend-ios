//
//  User+CoreDataProperties.swift
//  bib-app
//
//  Created by Daniel Schäfer / PBD2H24A on 11.06.26.
//
//

import Foundation
import CoreData


public typealias UserCoreDataPropertiesSet = NSSet

extension User {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<User> {
        return NSFetchRequest<User>(entityName: "User")
    }

    @NSManaged public var email: String?
    @NSManaged public var klasse: String?
    @NSManaged public var nachname: String?
    @NSManaged public var vorname: String?

}

extension User : Identifiable {

}

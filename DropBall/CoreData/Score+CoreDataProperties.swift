//
//  Score+CoreDataProperties.swift
//  DropBall
//
//  Created by Jordan Horacsek on 2022-12-15.
//
//

import Foundation
import CoreData


extension Score {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Score> {
        return NSFetchRequest<Score>(entityName: "Score")
    }

    @NSManaged public var name: String?
    @NSManaged public var score: Int64

    /// When the score was set. Optional because rows saved before this attribute existed
    /// have no value and can't be backfilled — a nil date means "saved before dates were
    /// recorded", not "unknown".
    @NSManaged public var date: Date?

}

extension Score : Identifiable {

}

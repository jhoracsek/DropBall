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

}

extension Score : Identifiable {

}

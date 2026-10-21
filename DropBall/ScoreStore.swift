//
//  ScoreStore.swift
//  DropBall
//

import Foundation
import CoreData

/// The saved score table.
///
/// Consolidates the Core Data access that was previously spread across GameScene and
/// HighscoreScene, which each built their own fetch requests. One place also gives the
/// retention limit somewhere to live.
enum ScoreStore {

    /// How many scores are kept. Everything below this is discarded whenever a new score is
    /// recorded, so the table stays a leaderboard rather than growing into a log of every
    /// game ever played — which is what it was, since nothing ever pruned it.
    static let keepCount = 20

    private static var context: NSManagedObjectContext {
        AppDelegate.sharedAppDelegate.coreDataStack.managedContext
    }

    /// Saves a score, then trims the table back to `keepCount`.
    static func record(_ value: Int) {
        let entry = Score(context: context)
        entry.score = Int64(value)
        entry.date = Date()

        AppDelegate.sharedAppDelegate.coreDataStack.saveContext()

        prune()
    }

    /// The best `limit` scores, highest first.
    static func top(_ limit: Int = keepCount) -> [Score] {
        let request: NSFetchRequest<Score> = Score.fetchRequest()
        request.fetchLimit = limit
        request.sortDescriptors = sortByScore

        do {
            return try context.fetch(request)
        } catch let error as NSError {
            print("Score fetch error: \(error) description: \(error.userInfo)")
            return []
        }
    }

    /// The highest score on record, or nil if there are none yet.
    static func best() -> Int? {
        top(1).first.map { Int($0.score) }
    }

    /// Clears the table. Used by the debug reset button.
    static func removeAll() {
        let request: NSFetchRequest<Score> = Score.fetchRequest()

        do {
            for row in try context.fetch(request) {
                context.delete(row)
            }
            AppDelegate.sharedAppDelegate.coreDataStack.saveContext()
        } catch let error as NSError {
            print("Score reset error: \(error) description: \(error.userInfo)")
        }
    }

    /// Drops everything past `keepCount`.
    ///
    /// Fetches from the cut-off onwards rather than loading the whole table and slicing it,
    /// so the work is proportional to what's being deleted rather than to how much has
    /// accumulated. Deleted through the context rather than with an NSBatchDeleteRequest,
    /// which would bypass it and leave objects in memory that no longer exist in the store.
    private static func prune() {
        let request: NSFetchRequest<Score> = Score.fetchRequest()
        request.sortDescriptors = sortByScore
        request.fetchOffset = keepCount

        do {
            let surplus = try context.fetch(request)
            guard !surplus.isEmpty else { return }

            for row in surplus {
                context.delete(row)
            }
            AppDelegate.sharedAppDelegate.coreDataStack.saveContext()
        } catch let error as NSError {
            print("Score prune error: \(error) description: \(error.userInfo)")
        }
    }

    /// Ties are broken by date so the ordering is stable between fetches — without a second
    /// key, equal scores could come back in any order and the list would reshuffle itself.
    private static var sortByScore: [NSSortDescriptor] {
        [NSSortDescriptor(key: #keyPath(Score.score), ascending: false),
         NSSortDescriptor(key: #keyPath(Score.date), ascending: false)]
    }
}

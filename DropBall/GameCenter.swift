//
//  GameCenter.swift
//  DropBall
//

import Foundation
import GameKit
import UIKit

/// Game Center leaderboard support: signing the player in, submitting scores, and opening
/// the system leaderboard UI.
///
/// Local scores in [ScoreStore] are kept regardless — Game Center needs a signed-in player
/// and a network, and the game has to work without either.
enum GameCenter {

    /// Must match the Leaderboard ID set in App Store Connect exactly. Note that this is the
    /// *ID*, not the reference name — the reference name never appears in code.
    static let leaderboardID = "com.toastedwalnuts.DropBall.highscores"

    /// A score that couldn't be submitted because nobody was signed in yet, held until the
    /// next successful authentication.
    ///
    /// GameKit retries submissions itself once a player is authenticated, so this only
    /// covers the window before that happens — which is easy to hit, because a first run can
    /// finish well before the sign-in round trip does. The leaderboard keeps best scores, so
    /// one value is enough; a lower pending score would be discarded server-side anyway.
    private static let pendingScoreKey = "GameCenterPendingScore"

    static var isAuthenticated: Bool {
        GKLocalPlayer.local.isAuthenticated
    }

    // MARK: - Authentication

    /// Starts sign-in. Call once per launch, as early as there's a window to present from.
    ///
    /// The handler is also called again later by GameKit — on sign-out, or when the player
    /// switches accounts — so it has to stay valid for the life of the app rather than being
    /// treated as a one-shot callback.
    static func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { viewController, error in
            if let viewController {
                present(viewController)
                return
            }

            if let error {
                // Not worth surfacing: declining sign-in, or having no network, both land
                // here, and neither stops the game being playable.
                print("Game Center authentication failed: \(error.localizedDescription)")
                return
            }

            #if DEBUG
            print("Game Center: signed in as \(GKLocalPlayer.local.displayName)")
            #endif

            submitPendingScore()
        }
    }

    // MARK: - Submitting

    /// Submits a score, or holds it until the player is signed in.
    static func submit(_ score: Int) {
        guard isAuthenticated else {
            holdPendingScore(score)
            return
        }

        GKLeaderboard.submitScore(score,
                                  context: 0,
                                  player: GKLocalPlayer.local,
                                  leaderboardIDs: [leaderboardID]) { error in
            if let error {
                // Hold onto it so the next sign-in retries, rather than losing the run.
                holdPendingScore(score)
                print("Game Center score submission failed: \(error.localizedDescription)")
                return
            }

            // A successful submission is otherwise completely silent, which makes "is this
            // wired up at all?" impossible to answer without opening the leaderboard.
            #if DEBUG
            print("Game Center: submitted \(score) to \(leaderboardID)")
            #endif
        }
    }

    private static func holdPendingScore(_ score: Int) {
        let existing = UserDefaults.standard.integer(forKey: pendingScoreKey)
        if score > existing {
            UserDefaults.standard.set(score, forKey: pendingScoreKey)
        }
    }

    private static func submitPendingScore() {
        let pending = UserDefaults.standard.integer(forKey: pendingScoreKey)
        guard pending > 0 else { return }

        // Cleared up front so a failure doesn't re-hold the same value through submit() and
        // leave it stuck; submit() will put it back if the attempt fails.
        UserDefaults.standard.removeObject(forKey: pendingScoreKey)
        submit(pending)
    }

    // MARK: - Reading

    /// One row of the global leaderboard, reduced to what the game draws.
    ///
    /// Flattened out of GKLeaderboard.Entry so the scene doesn't carry GameKit types around
    /// and can be laid out against stub data.
    struct Entry {
        let rank: Int
        let name: String
        let score: Int
        let isLocalPlayer: Bool
    }

    /// The top of the leaderboard plus where the local player sits in it.
    struct Standings {
        let entries: [Entry]

        /// Nil when the player has no score on the board yet — which is different from
        /// being ranked last, so it can't be folded into `entries`.
        let localRank: Int?
        let totalPlayers: Int
    }

    enum LoadError: Error {
        /// The ID in `leaderboardID` doesn't match a leaderboard App Store Connect will
        /// serve. Usually a typo, or a board that hasn't gone live yet.
        case leaderboardUnavailable
    }

    /// Loads the top `limit` scores. Throws rather than returning an empty list, so the
    /// caller can tell "nobody has played" apart from "the network is down".
    static func loadTopScores(limit: Int = ScoreStore.keepCount) async throws -> Standings {
        let boards = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboardID])
        guard let board = boards.first else { throw LoadError.leaderboardUnavailable }

        // Ranks are 1-based, and GameKit caps a single request at 100 rows.
        let range = NSRange(location: 1, length: min(limit, 100))
        let (localEntry, topEntries, totalPlayers) = try await board.loadEntries(for: .global,
                                                                                timeScope: .allTime,
                                                                                range: range)

        let localID = GKLocalPlayer.local.gamePlayerID
        let entries = topEntries.map { entry in
            Entry(rank: entry.rank,
                  name: entry.player.displayName,
                  score: entry.score,
                  isLocalPlayer: entry.player.gamePlayerID == localID)
        }

        return Standings(entries: entries,
                         localRank: localEntry?.rank,
                         totalPlayers: totalPlayers)
    }

    // MARK: - Presenting

    /// Opens the system leaderboard. Does nothing if the player isn't signed in — Game
    /// Center shows an empty shell in that case, which reads as a bug.
    static func presentLeaderboard() {
        guard isAuthenticated else { return }

        let controller = GKGameCenterViewController(leaderboardID: leaderboardID,
                                                   playerScope: .global,
                                                   timeScope: .allTime)
        controller.gameCenterDelegate = dismissHandler
        present(controller)
    }

    /// GKGameCenterViewController doesn't dismiss itself; something has to act as its
    /// delegate and do it. Held statically because the controller's delegate is weak.
    private static let dismissHandler = DismissHandler()

    private final class DismissHandler: NSObject, GKGameCenterControllerDelegate {
        func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
            gameCenterViewController.dismiss(animated: true)
        }
    }

    private static func present(_ viewController: UIViewController) {
        guard let root = rootViewController, root.presentedViewController == nil else { return }
        root.present(viewController, animated: true)
    }

    /// The app's root view controller. Found through the connected scene rather than
    /// `UIApplication.shared.windows`, which is deprecated and wrong for a scene-based app.
    private static var rootViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}

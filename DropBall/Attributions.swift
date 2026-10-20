//
//  Attributions.swift
//  DropBall
//

import Foundation

/// A single third-party asset and its licence terms.
///
/// CC BY 4.0 — which the music is under — requires the creator's name, the title, a licence
/// notice, a link to the source where practicable, and an indication of any changes made.
/// Every field here maps to one of those obligations, so filling one in properly is enough
/// to stay compliant.
struct Attribution {
    let title: String
    let author: String

    /// Short licence name as shown, e.g. "CC BY 4.0".
    let licence: String

    /// Where the licence itself is published. Nil for licences with no canonical URL.
    let licenceURL: String?

    /// Where the asset came from.
    let sourceURL: String?

    /// Shown in place of the full URL, which is usually too long for the panel.
    let displayLink: String?

    /// What was changed, if anything. CC BY requires saying so; nil means used as supplied.
    let modifications: String?

    init(title: String,
         author: String,
         licence: String,
         licenceURL: String? = nil,
         sourceURL: String? = nil,
         displayLink: String? = nil,
         modifications: String? = nil) {
        self.title = title
        self.author = author
        self.licence = licence
        self.licenceURL = licenceURL
        self.sourceURL = sourceURL
        self.displayLink = displayLink
        self.modifications = modifications
    }
}

/// Everything the game ships that someone else made.
///
/// Add new assets here and the credits screen picks them up — it builds itself from this
/// list, so there's no layout to touch.
enum Attributions {

    static let all: [Attribution] = [
        Attribution(
            title: "Free Chiptune Music Pack 5",
            author: "ChillMindscapes",
            licence: "CC BY 4.0",
            licenceURL: "https://creativecommons.org/licenses/by/4.0/",
            sourceURL: "https://chillmindscapes.itch.io/free-chiptune-music-pack-5-chillmindscapes",
            displayLink: "chillmindscapes.itch.io",
            // Update this if the tracks are re-encoded or trimmed before shipping — CC BY
            // requires stating that the material was changed.
            modifications: nil
        ),
        Attribution(
            title: "Pixel Operator",
            author: "Jayvee Enaguas (HarvettFox96)",
            licence: "CC0 1.0 (Public Domain)",
            licenceURL: "https://creativecommons.org/publicdomain/zero/1.0/",
            sourceURL: "https://www.dafont.com/pixel-operator.font",
            displayLink: "dafont.com",
            modifications: nil
        )
    ]
}

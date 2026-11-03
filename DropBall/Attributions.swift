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

    /// The licence reproduced in full, for licences that require the text itself to ship
    /// rather than just a notice and a link. Paragraphs separated by blank lines; the
    /// credits screen re-flows them to fit. Nil where a link is enough.
    let licenceText: String?

    init(title: String,
         author: String,
         licence: String,
         licenceURL: String? = nil,
         sourceURL: String? = nil,
         displayLink: String? = nil,
         modifications: String? = nil,
         licenceText: String? = nil) {
        self.title = title
        self.author = author
        self.licence = licence
        self.licenceURL = licenceURL
        self.sourceURL = sourceURL
        self.displayLink = displayLink
        self.modifications = modifications
        self.licenceText = licenceText
    }
}

/// Full licence texts, for the licences that require shipping the text itself.
enum Licences {

    /// The MIT licence, verbatim, with the copyright line filled in.
    ///
    /// MIT asks that "the above copyright notice and this permission notice" travel with
    /// every copy — a link to the terms doesn't discharge that, so the text ships in the app.
    static func mit(copyright: String) -> String {
        """
        MIT License

        Copyright (c) \(copyright)

        Permission is hereby granted, free of charge, to any person obtaining a copy of \
        this software and associated documentation files (the "Software"), to deal in the \
        Software without restriction, including without limitation the rights to use, copy, \
        modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, \
        and to permit persons to whom the Software is furnished to do so, subject to the \
        following conditions:

        The above copyright notice and this permission notice shall be included in all \
        copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, \
        INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A \
        PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT \
        HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION \
        OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE \
        SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
        """
    }
}

/// Everything the game ships that someone else made.
///
/// Add new assets here and the credits screen picks them up — it builds itself from this
/// list, so there's no layout to touch.
enum Attributions {

    /// Who made the game itself, shown above the third-party assets.
    static let gameTitle = "DropBall"
    static let creator = "Jordan Horacsek"

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
            title: "Stringstar Fields",
            author: "Trixie (trixelized)",
            licence: "MIT",
            licenceURL: "https://opensource.org/license/mit",
            sourceURL: "https://trixelized.itch.io/starstring-fields",
            displayLink: "trixelized.itch.io",
            // MIT permits modification without requiring it to be declared, but saying so
            // costs nothing. Adjust if the art was used differently from this.
            modifications: "Adapted for the background layers",
            // Neither the itch.io page nor the download carries a copyright line, so the
            // author's name stands in for one. Replace this with the exact notice if Trixie
            // provides one.
            licenceText: Licences.mit(copyright: "Trixie (trixelized)")
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

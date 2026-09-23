import Foundation

/// One part of a Coach prompt. Text is the words. A photo is a file the
/// model session attaches beside those words, with a label the vision tools
/// can name.
enum CoachPromptPiece: Equatable, Sendable {
    case text(String)
    case photo(fileName: String, label: String)
}

/// Builds the prompt for one reply. A live session already holds earlier
/// photos, so those are attached again only when `earlierTurns` is present
/// (a new session seeded from the saved chat).
enum CoachPrompt {
    /// How many earlier photos a seeded session reattaches. The current
    /// message's photos are always included on top of this.
    static let maxEarlierPhotos = 4

    static func pieces(
        userMessage: String,
        currentPhotoFileNames: [String],
        earlierTurns: [CoachChatTurn]?,
        includeEarlierPhotos: Bool,
        framing: [String],
        maxEarlierTurns: Int,
        maxCharactersPerTurn: Int
    ) -> [CoachPromptPiece] {
        var pieces: [CoachPromptPiece] = []
        if let earlierTurns, !earlierTurns.isEmpty {
            let window = Array(earlierTurns.suffix(max(0, maxEarlierTurns)))
            let includedPhotos = earlierPhotoNames(in: window, include: includeEarlierPhotos)
            var earlierIndex = 0
            var started = false
            for turn in window {
                let speaker = turn.role == .user ? "User" : "Coach"
                var text = turn.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if text.count > maxCharactersPerTurn {
                    text = String(text.prefix(maxCharactersPerTurn)) + "…"
                }
                let attachedHere = turn.photoFileNames.contains { includedPhotos.contains($0) }
                let photoNote = !turn.photoFileNames.isEmpty && !attachedHere ? " [a photo was attached]" : ""
                guard !text.isEmpty || !turn.photoFileNames.isEmpty else { continue }
                if !started {
                    pieces.append(.text("EARLIER IN THIS CHAT (oldest first):"))
                    started = true
                }
                if text.isEmpty {
                    pieces.append(.text("\(speaker):\(photoNote)"))
                } else {
                    pieces.append(.text("\(speaker): \(text)\(photoNote)"))
                }
                if attachedHere {
                    for name in turn.photoFileNames where includedPhotos.contains(name) {
                        earlierIndex += 1
                        pieces.append(.photo(fileName: name, label: "earlier-\(earlierIndex)"))
                    }
                }
            }
        }

        for line in framing {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                pieces.append(.text(trimmed))
            }
        }

        let caption = userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let photos = currentPhotoFileNames.filter { !$0.isEmpty }
        if !caption.isEmpty {
            pieces.append(.text(caption))
        } else if !photos.isEmpty {
            pieces.append(.text(photos.count == 1 ? "The person sent this photo." : "The person sent these photos."))
        }
        for (index, name) in photos.enumerated() {
            pieces.append(.photo(fileName: name, label: "photo-\(index + 1)"))
        }
        return pieces
    }

    private static func earlierPhotoNames(in turns: [CoachChatTurn], include: Bool) -> Set<String> {
        guard include else { return [] }
        let names = turns.filter { $0.role == .user }.flatMap(\.photoFileNames)
        return Set(names.suffix(maxEarlierPhotos))
    }
}

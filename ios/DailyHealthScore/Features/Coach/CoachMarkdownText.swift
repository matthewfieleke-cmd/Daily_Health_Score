import SwiftUI

/// Renders the Coach's light Markdown: paragraphs with **bold**, short bullet
/// and numbered lists. Anything else falls back to plain text.
struct CoachMarkdownText: View {
    let text: String
    var font: Font = .body

    var body: some View {
        let blocks = CoachMarkdown.blocks(from: text)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .paragraph(let paragraph):
                    inline(paragraph)
                        .font(font)
                        .fixedSize(horizontal: false, vertical: true)
                case .bullets(let items):
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("•")
                                    .font(font)
                                inline(item)
                                    .font(font)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                case .numbered(let items):
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("\(index + 1).")
                                    .font(font)
                                    .monospacedDigit()
                                inline(item)
                                    .font(font)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(CoachMarkdown.plainText(text))
    }

    private func inline(_ string: String) -> Text {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        if let attributed = try? AttributedString(markdown: string, options: options) {
            return Text(attributed)
        }
        return Text(string)
    }
}

import Foundation

indirect enum MathNode: Equatable, Sendable {
    case sequence(id: UUID, children: [MathNode])
    case slot(id: UUID, text: String)
    case fraction(id: UUID, numerator: MathNode, denominator: MathNode)
    case radical(id: UUID, radicand: MathNode)
    case superscript(id: UUID, exponent: MathNode)
    case subscriptNode(id: UUID, subscriptValue: MathNode)
    case absolute(id: UUID, content: MathNode)
    case parentheses(id: UUID, content: MathNode)
    case function(id: UUID, name: String, argument: MathNode)
    /// Big operator (Σ/∫/lim/log…) with editable upper/lower limit boxes.
    /// Rendering: name centered with `upper` above and `lower` below.
    case limitsOperator(id: UUID, name: String, upper: MathNode, lower: MathNode)

    static func emptySequence() -> MathNode {
        .sequence(id: UUID(), children: [.slot(id: UUID(), text: "")])
    }

    static func emptySlotSequence() -> MathNode {
        .sequence(id: UUID(), children: [.slot(id: UUID(), text: "")])
    }

    var id: UUID {
        switch self {
        case let .sequence(id, _), let .slot(id, _), let .fraction(id, _, _),
             let .radical(id, _), let .superscript(id, _),
             let .subscriptNode(id, _), let .absolute(id, _),
             let .parentheses(id, _), let .function(id, _, _),
             let .limitsOperator(id, _, _, _):
            id
        }
    }

    /// True when the subtree contains no non-whitespace slot text.
    var isBlank: Bool {
        switch self {
        case let .slot(_, text):
            text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case let .sequence(_, children):
            children.allSatisfy(\.isBlank)
        case let .fraction(_, numerator, denominator):
            numerator.isBlank && denominator.isBlank
        case let .radical(_, radicand), let .superscript(_, radicand),
             let .subscriptNode(_, radicand), let .absolute(_, radicand),
             let .parentheses(_, radicand):
            radicand.isBlank
        case let .function(_, _, argument):
            argument.isBlank
        case let .limitsOperator(_, _, upper, lower):
            upper.isBlank && lower.isBlank
        }
    }

    var slotIDs: [UUID] {
        switch self {
        case let .slot(id, _):
            [id]
        case let .sequence(_, children):
            children.flatMap(\.slotIDs)
        case let .fraction(_, numerator, denominator):
            numerator.slotIDs + denominator.slotIDs
        case let .radical(_, radicand), let .superscript(_, radicand),
             let .subscriptNode(_, radicand), let .absolute(_, radicand),
             let .parentheses(_, radicand):
            radicand.slotIDs
        case let .function(_, _, argument):
            argument.slotIDs
        case let .limitsOperator(_, _, upper, lower):
            // lower first so Tab lands in the lower box right after insertion.
            lower.slotIDs + upper.slotIDs
        }
    }

    var latex: String {
        switch self {
        case let .sequence(_, children):
            return children.map(\.latex).joined()
        case let .slot(_, text):
            return text.asLatex
        case let .fraction(_, numerator, denominator):
            return "\\frac{\(numerator.latex)}{\(denominator.latex)}"
        case let .radical(_, radicand):
            return "\\sqrt{\(radicand.latex)}"
        case let .superscript(_, exponent):
            return "^{\(exponent.latex)}"
        case let .subscriptNode(_, subscriptValue):
            return "_{\(subscriptValue.latex)}"
        case let .absolute(_, content):
            return "\\left|\(content.latex)\\right|"
        case let .parentheses(_, content):
            return "\\left(\(content.latex)\\right)"
        case let .function(_, name, argument):
            return "\(name.asFunctionLatex)\\left(\(argument.latex)\\right)"
        case let .limitsOperator(_, name, upper, lower):
            let command = name.limitsCommand
            var result = command
            if !lower.isBlank { result += "_{\(lower.latex)}" }
            if !upper.isBlank { result += "^{\(upper.latex)}" }
            return result
        }
    }

    var plainText: String {
        switch self {
        case let .sequence(_, children):
            return children.map(\.plainText).joined()
        case let .slot(_, text):
            return text
        case let .fraction(_, numerator, denominator):
            return "(\(numerator.plainText))⁄(\(denominator.plainText))"
        case let .radical(_, radicand):
            return "√(\(radicand.plainText))"
        case let .superscript(_, exponent):
            return exponent.plainText.asSuperscript ?? "^(\(exponent.plainText))"
        case let .subscriptNode(_, subscriptValue):
            return subscriptValue.plainText.asSubscript ?? "_(\(subscriptValue.plainText))"
        case let .absolute(_, content):
            return "|\(content.plainText)|"
        case let .parentheses(_, content):
            return "(\(content.plainText))"
        case let .function(_, name, argument):
            return "\(name)(\(argument.plainText))"
        case let .limitsOperator(_, name, upper, lower):
            let lowerText = lower.plainText
            let upperText = upper.plainText
            var result = name
            if !lowerText.isEmpty {
                result += lowerText.asSubscript ?? "_(\(lowerText))"
            }
            if !upperText.isEmpty {
                result += upperText.asSuperscript ?? "^(\(upperText))"
            }
            return result
        }
    }

    func text(for slotID: UUID) -> String? {
        switch self {
        case let .slot(id, text):
            id == slotID ? text : nil
        case let .sequence(_, children):
            children.lazy.compactMap { $0.text(for: slotID) }.first
        case let .fraction(_, numerator, denominator):
            numerator.text(for: slotID) ?? denominator.text(for: slotID)
        case let .radical(_, content), let .superscript(_, content),
             let .subscriptNode(_, content), let .absolute(_, content),
             let .parentheses(_, content):
            content.text(for: slotID)
        case let .function(_, _, argument):
            argument.text(for: slotID)
        case let .limitsOperator(_, _, upper, lower):
            upper.text(for: slotID) ?? lower.text(for: slotID)
        }
    }

    func updatingSlot(_ slotID: UUID, text: String) -> MathNode {
        switch self {
        case let .slot(id, oldText):
            .slot(id: id, text: id == slotID ? text : oldText)
        case let .sequence(id, children):
            .sequence(id: id, children: children.map { $0.updatingSlot(slotID, text: text) })
        case let .fraction(id, numerator, denominator):
            .fraction(
                id: id,
                numerator: numerator.updatingSlot(slotID, text: text),
                denominator: denominator.updatingSlot(slotID, text: text)
            )
        case let .radical(id, content):
            .radical(id: id, radicand: content.updatingSlot(slotID, text: text))
        case let .superscript(id, content):
            .superscript(id: id, exponent: content.updatingSlot(slotID, text: text))
        case let .subscriptNode(id, content):
            .subscriptNode(id: id, subscriptValue: content.updatingSlot(slotID, text: text))
        case let .absolute(id, content):
            .absolute(id: id, content: content.updatingSlot(slotID, text: text))
        case let .parentheses(id, content):
            .parentheses(id: id, content: content.updatingSlot(slotID, text: text))
        case let .function(id, name, argument):
            .function(id: id, name: name, argument: argument.updatingSlot(slotID, text: text))
        case let .limitsOperator(id, name, upper, lower):
            .limitsOperator(
                id: id,
                name: name,
                upper: upper.updatingSlot(slotID, text: text),
                lower: lower.updatingSlot(slotID, text: text)
            )
        }
    }

    /// Inserts a structural node immediately after the selected slot in its
    /// nearest sequence, preserving the text already entered in that slot.
    func inserting(after slotID: UUID, node: MathNode, trailingSlotID: UUID) -> MathNode {
        switch self {
        case let .sequence(id, children):
            if let index = children.firstIndex(where: { $0.id == slotID }) {
                var updated = children
                updated.insert(contentsOf: [node, .slot(id: trailingSlotID, text: "")], at: index + 1)
                return .sequence(id: id, children: updated)
            }
            return .sequence(
                id: id,
                children: children.map { $0.inserting(after: slotID, node: node, trailingSlotID: trailingSlotID) }
            )
        case .slot:
            return self
        case let .fraction(id, numerator, denominator):
            return .fraction(
                id: id,
                numerator: numerator.inserting(after: slotID, node: node, trailingSlotID: trailingSlotID),
                denominator: denominator.inserting(after: slotID, node: node, trailingSlotID: trailingSlotID)
            )
        case let .radical(id, content):
            return .radical(id: id, radicand: content.inserting(after: slotID, node: node, trailingSlotID: trailingSlotID))
        case let .superscript(id, content):
            return .superscript(id: id, exponent: content.inserting(after: slotID, node: node, trailingSlotID: trailingSlotID))
        case let .subscriptNode(id, content):
            return .subscriptNode(id: id, subscriptValue: content.inserting(after: slotID, node: node, trailingSlotID: trailingSlotID))
        case let .absolute(id, content):
            return .absolute(id: id, content: content.inserting(after: slotID, node: node, trailingSlotID: trailingSlotID))
        case let .parentheses(id, content):
            return .parentheses(id: id, content: content.inserting(after: slotID, node: node, trailingSlotID: trailingSlotID))
        case let .function(id, name, argument):
            return .function(
                id: id,
                name: name,
                argument: argument.inserting(after: slotID, node: node, trailingSlotID: trailingSlotID)
            )
        case let .limitsOperator(id, name, upper, lower):
            return .limitsOperator(
                id: id,
                name: name,
                upper: upper.inserting(after: slotID, node: node, trailingSlotID: trailingSlotID),
                lower: lower.inserting(after: slotID, node: node, trailingSlotID: trailingSlotID)
            )
        }
    }

    func insertingSlot(after slotID: UUID, newSlotID: UUID) -> MathNode {
        switch self {
        case let .sequence(id, children):
            if let index = children.firstIndex(where: { $0.id == slotID }) {
                var updated = children
                updated.insert(.slot(id: newSlotID, text: ""), at: index + 1)
                return .sequence(id: id, children: updated)
            }
            return .sequence(
                id: id,
                children: children.map { $0.insertingSlot(after: slotID, newSlotID: newSlotID) }
            )
        case .slot:
            return self
        case let .fraction(id, numerator, denominator):
            return .fraction(
                id: id,
                numerator: numerator.insertingSlot(after: slotID, newSlotID: newSlotID),
                denominator: denominator.insertingSlot(after: slotID, newSlotID: newSlotID)
            )
        case let .radical(id, content):
            return .radical(id: id, radicand: content.insertingSlot(after: slotID, newSlotID: newSlotID))
        case let .superscript(id, content):
            return .superscript(id: id, exponent: content.insertingSlot(after: slotID, newSlotID: newSlotID))
        case let .subscriptNode(id, content):
            return .subscriptNode(id: id, subscriptValue: content.insertingSlot(after: slotID, newSlotID: newSlotID))
        case let .absolute(id, content):
            return .absolute(id: id, content: content.insertingSlot(after: slotID, newSlotID: newSlotID))
        case let .parentheses(id, content):
            return .parentheses(id: id, content: content.insertingSlot(after: slotID, newSlotID: newSlotID))
        case let .function(id, name, argument):
            return .function(id: id, name: name, argument: argument.insertingSlot(after: slotID, newSlotID: newSlotID))
        case let .limitsOperator(id, name, upper, lower):
            return .limitsOperator(
                id: id,
                name: name,
                upper: upper.insertingSlot(after: slotID, newSlotID: newSlotID),
                lower: lower.insertingSlot(after: slotID, newSlotID: newSlotID)
            )
        }
    }
}

private extension String {
    /// Function-like tokens that LaTeX must render upright (trig, log, etc.).
    var namedFunctions: [String] {
        ["arcsin", "arccos", "arctan", "sin", "cos", "tan", "cot",
         "sec", "csc", "log", "ln", "lg", "lim", "max", "min"]
    }

    /// LaTeX command for big operators with upper/lower limits.
    var limitsCommand: String {
        switch self {
        case "Σ": return "\\sum "
        case "∫": return "\\int "
        case "∏": return "\\prod "
        case "lim": return "\\lim "
        case "log": return "\\log "
        case "ln": return "\\ln "
        case "lg": return "\\lg "
        case "max": return "\\max "
        case "min": return "\\min "
        default: return asLatex
        }
    }

    var asFunctionLatex: String {
        namedFunctions.contains(self) ? "\\\(self) " : asLatex
    }

    var asLatex: String {
        var normalized = self
        // Mark function tokens first so longer names (e.g. arcsin) are not
        // corrupted by later replacements of shorter substrings (e.g. sin).
        var markers: [String] = []
        for (index, function) in namedFunctions.enumerated() {
            let marker = "\u{1F600}\(index)\u{1F601}" // emoji sentinel, unused in math text
            normalized = normalized.replacingOccurrences(of: function, with: marker)
            markers.append(marker)
        }
        let replacements: [Character: String] = [
            "π": "\\pi ", "θ": "\\theta ", "α": "\\alpha ", "β": "\\beta ",
            "γ": "\\gamma ", "Δ": "\\Delta ", "≤": "\\le ", "≥": "\\ge ",
            "≠": "\\ne ", "±": "\\pm ", "∞": "\\infty ", "∈": "\\in ",
            "∪": "\\cup ", "∩": "\\cap ", "Σ": "\\sum ", "∫": "\\int ",
            "→": "\\to ", "×": "\\times ", "÷": "\\div ", "·": "\\cdot ",
            "−": "-", "′": "'", "″": "''", "⁰": "^{0}", "¹": "^{1}",
            "²": "^{2}", "³": "^{3}", "⁴": "^{4}", "⁵": "^{5}",
            "⁶": "^{6}", "⁷": "^{7}", "⁸": "^{8}", "⁹": "^{9}",
            "⁽": "^{(", "ⁿ": "n", "⁾": ")}", "ˣ": "^{x}"
        ]
        normalized = normalized.map { replacements[$0] ?? String($0) }.joined()
        for (index, marker) in markers.enumerated() {
            normalized = normalized.replacingOccurrences(of: marker, with: "\\\(namedFunctions[index]) ")
        }
        return normalized
    }

    var asSuperscript: String? {
        transformed(using: [
            "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
            "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹",
            "+": "⁺", "-": "⁻", "−": "⁻", "=": "⁼", "(": "⁽", ")": "⁾", "n": "ⁿ"
        ])
    }

    var asSubscript: String? {
        transformed(using: [
            "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄",
            "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
            "+": "₊", "-": "₋", "−": "₋", "=": "₌", "(": "₍", ")": "₎",
            "a": "ₐ", "e": "ₑ", "i": "ᵢ", "n": "ₙ", "o": "ₒ", "x": "ₓ"
        ])
    }

    func transformed(using replacements: [Character: Character]) -> String? {
        var result = ""
        for character in self {
            guard let replacement = replacements[character] else { return nil }
            result.append(replacement)
        }
        return result
    }
}

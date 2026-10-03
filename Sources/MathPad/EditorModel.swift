import AppKit
import Combine
import Foundation

enum StructureKind: String, CaseIterable, Identifiable, Sendable {
    case fraction = "分数"
    case radical = "根号"
    case superscript = "上标"
    case subscriptNode = "下标"
    case absolute = "绝对值"
    case parentheses = "括号"

    var id: String { rawValue }
}

enum OutputFormat: String, CaseIterable, Identifiable, Sendable {
    case latex = "LaTeX"
    case plainText = "纯文本"
    case markdownInline = "Markdown 行内"
    case markdownBlock = "Markdown 块"

    var id: String { rawValue }

    func render(latex: String, plainText: String) -> String {
        switch self {
        case .latex:
            return latex
        case .plainText:
            return plainText
        case .markdownInline:
            return "$\(latex)$"
        case .markdownBlock:
            return "$$\n\(latex)\n$$"
        }
    }
}

struct HistoryEntry: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let latex: String
    let createdAt: Date
    let formatName: String?
}

struct SymbolUsageState: Codable, Equatable, Sendable {
    var counts: [String: Int] = [:]
    var recent: [String] = []

    mutating func record(_ symbol: String) {
        counts[symbol, default: 0] += 1
        recent.removeAll { $0 == symbol }
        recent.insert(symbol, at: 0)
        recent = Array(recent.prefix(8))
    }

    var frequent: [String] {
        counts.keys.sorted { left, right in
            let leftCount = counts[left, default: 0]
            let rightCount = counts[right, default: 0]
            if leftCount != rightCount { return leftCount > rightCount }
            let leftRecent = recent.firstIndex(of: left) ?? .max
            let rightRecent = recent.firstIndex(of: right) ?? .max
            if leftRecent != rightRecent { return leftRecent < rightRecent }
            return left < right
        }
    }
}

@MainActor
final class EditorModel: ObservableObject {
    @Published private(set) var root: MathNode
    @Published var activeSlotID: UUID?
    @Published private(set) var history: [HistoryEntry] = []
    @Published var selectedOutputFormat: OutputFormat = .plainText
    @Published private(set) var symbolUsage = SymbolUsageState()

    var onHide: (() -> Void)?
    private let defaults: UserDefaults
    private let historyKey = "MathPad.history.v1"
    private let symbolUsageKey = "MathPad.symbolUsage.v1"
    private let defaultFrequentSymbols = ["=", ",", "π", "≤", "≥", "∞"]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let initial = MathNode.emptySequence()
        root = initial
        activeSlotID = initial.slotIDs.first
        loadHistory()
        loadSymbolUsage()
    }

    var latex: String { root.latex.trimmingCharacters(in: .whitespacesAndNewlines) }
    var formattedOutput: String {
        selectedOutputFormat.render(latex: latex, plainText: root.plainText)
    }
    var frequentSymbols: [String] {
        let recorded = Array(symbolUsage.frequent.prefix(8))
        return recorded.isEmpty ? defaultFrequentSymbols : recorded
    }
    var recentSymbols: [String] { symbolUsage.recent }

    func text(for id: UUID) -> String { root.text(for: id) ?? "" }

    func updateSlot(id: UUID, text: String) {
        root = root.updatingSlot(id, text: text)
        activeSlotID = id
    }

    func selectSlot(_ id: UUID) {
        guard root.slotIDs.contains(id) else { return }
        activeSlotID = id
    }

    func insertSymbol(_ symbol: String) {
        let functions = ["f", "g", "sin", "cos", "tan", "cot", "sec", "csc", "arcsin", "arccos", "arctan"]
        let name = symbol.replacingOccurrences(of: "(□)", with: "")
        if functions.contains(name) {
            insertFunction(name)
            return
        }
        if ["Σ", "∫", "lim", "log", "ln", "lg"].contains(name) {
            insertLimitsOperator(name)
            return
        }
        guard activeSlotID != nil else { return }
        insertInput(symbol)
        symbolUsage.record(symbol)
        persistSymbolUsage()
    }

    func insertInput(_ value: String) {
        guard let id = activeSlotID else { return }
        let updated = SlotFocusRegistry.shared.inserting(value, in: id) ?? (text(for: id) + value)
        updateSlot(id: id, text: updated)
    }

    func deleteBackward() {
        guard let id = activeSlotID else { return }
        updateSlot(id: id, text: String(text(for: id).dropLast()))
    }

    func addSlotAfterSelection() {
        guard let selected = activeSlotID else { return }
        let newSlot = UUID()
        root = root.insertingSlot(after: selected, newSlotID: newSlot)
        activeSlotID = newSlot
    }

    func insertStructure(_ kind: StructureKind) {
        guard let selected = activeSlotID else { return }
        let firstInnerSlot = UUID()
        let inner = MathNode.sequence(
            id: UUID(),
            children: [.slot(id: firstInnerSlot, text: "")]
        )
        let node: MathNode
        switch kind {
        case .fraction:
            let denominatorSlot = UUID()
            node = .fraction(
                id: UUID(),
                numerator: inner,
                denominator: .sequence(id: UUID(), children: [.slot(id: denominatorSlot, text: "")])
            )
        case .radical:
            node = .radical(id: UUID(), radicand: inner)
        case .superscript:
            node = .superscript(id: UUID(), exponent: inner)
        case .subscriptNode:
            node = .subscriptNode(id: UUID(), subscriptValue: inner)
        case .absolute:
            node = .absolute(id: UUID(), content: inner)
        case .parentheses:
            node = .parentheses(id: UUID(), content: inner)
        }
        root = root.inserting(after: selected, node: node, trailingSlotID: UUID())
        activeSlotID = firstInnerSlot
    }

    func insertFunction(_ name: String) {
        guard let selected = activeSlotID else { return }
        let argumentSlot = UUID()
        let argument = MathNode.sequence(
            id: UUID(),
            children: [.slot(id: argumentSlot, text: "")]
        )
        let node = MathNode.function(id: UUID(), name: name, argument: argument)
        root = root.inserting(after: selected, node: node, trailingSlotID: UUID())
        activeSlotID = argumentSlot
        symbolUsage.record("\(name)(□)")
        persistSymbolUsage()
    }

    /// Inserts a big operator (Σ/∫/lim/log/…) with editable upper/lower limit
    /// boxes. Cursor lands in the lower box first; Tab walks to the upper box.
    func insertLimitsOperator(_ name: String) {
        guard let selected = activeSlotID else { return }
        let upperSlot = UUID()
        let lowerSlot = UUID()
        let limits = MathNode.limitsOperator(
            id: UUID(),
            name: name,
            upper: .sequence(id: UUID(), children: [.slot(id: upperSlot, text: "")]),
            lower: .sequence(id: UUID(), children: [.slot(id: lowerSlot, text: "")])
        )
        let node: MathNode
        if ["log", "ln", "lg"].contains(name) {
            node = .sequence(id: UUID(), children: [
                limits,
                .parentheses(id: UUID(), content: .emptySequence())
            ])
        } else {
            node = limits
        }
        root = root.inserting(after: selected, node: node, trailingSlotID: UUID())
        activeSlotID = lowerSlot
        SlotFocusRegistry.shared.focus(lowerSlot)
        symbolUsage.record(name)
        persistSymbolUsage()
    }

    func moveSlot(backward: Bool) {
        let ids = root.slotIDs
        guard !ids.isEmpty else { return }
        guard let active = activeSlotID, let index = ids.firstIndex(of: active) else {
            activeSlotID = ids.first
            return
        }
        let offset = backward ? -1 : 1
        let destination = ids[(index + offset + ids.count) % ids.count]
        activeSlotID = destination
        SlotFocusRegistry.shared.focus(destination)
    }

    func clear() {
        let initial = MathNode.emptySequence()
        root = initial
        activeSlotID = initial.slotIDs.first
    }

    @discardableResult
    func copyCurrentAndHide() -> Bool {
        guard !latex.isEmpty else { return false }
        let value = formattedOutput
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
        addHistory(value, format: selectedOutputFormat)
        clear()
        selectedOutputFormat = .plainText
        onHide?()
        return true
    }

    func copyHistory(_ entry: HistoryEntry) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.latex, forType: .string)
    }

    func deleteHistory() {
        history = []
        persistHistory()
    }

    private func addHistory(_ output: String, format: OutputFormat) {
        history.removeAll { $0.latex == output }
        history.insert(
            HistoryEntry(id: UUID(), latex: output, createdAt: Date(), formatName: format.rawValue),
            at: 0
        )
        history = Array(history.prefix(30))
        persistHistory()
    }

    private func loadHistory() {
        guard let data = defaults.data(forKey: historyKey),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) else { return }
        history = decoded
    }

    private func persistHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        defaults.set(data, forKey: historyKey)
    }

    private func loadSymbolUsage() {
        guard let data = defaults.data(forKey: symbolUsageKey),
              let decoded = try? JSONDecoder().decode(SymbolUsageState.self, from: data) else { return }
        symbolUsage = decoded
        // Migrate pre-structure shortcut labels while preserving usage counts.
        let oldLabels = ["f(x)": "f(□)", "g(x)": "g(□)", "sin(x)": "sin(□)",
                         "cos(x)": "cos(□)", "tan(x)": "tan(□)", "log(x)": "log",
                         "ln(x)": "ln", "f′(x)": "′", "f″(x)": "″",
                         "f⁽ⁿ⁾(x)": "′", "dy/dx": "′", "d²y/dx²": "″", "dⁿy/dxⁿ": "′"]
        var migrated = SymbolUsageState()
        for (label, count) in decoded.counts {
            migrated.counts[oldLabels[label] ?? label, default: 0] += count
        }
        for label in decoded.recent {
            let updated = oldLabels[label] ?? label
            if !migrated.recent.contains(updated) { migrated.recent.append(updated) }
        }
        symbolUsage = migrated
    }

    private func persistSymbolUsage() {
        guard let data = try? JSONEncoder().encode(symbolUsage) else { return }
        defaults.set(data, forKey: symbolUsageKey)
    }
}

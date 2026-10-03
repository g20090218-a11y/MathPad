import Foundation

enum SelfTest {
    private nonisolated(unsafe) static var checks = 0

    @discardableResult
    static func run() throws -> Int {
        checks = 0
        try nestedStructureExportsLatex()
        try commonSymbolsExportAsLatexCommands()
        try insertionPreservesExistingTextAndCreatesSlots()
        try slotInsertionAddsExactlyOneEditableSlot()
        try outputFormatsRenderExpectedText()
        try symbolUsageOrdersFrequentAndRecent()
        try newSlotReceivesSymbolWithoutChangingPreviousSlot()
        try functionAndDerivativeTemplatesExportLatex()
        try limitsOperatorExportsLatexAndPlainText()
        try limitsOperatorBlankLimitsAreOmitted()
        try trigFunctionsExportAsLatexCommands()
        return checks
    }

    private static func nestedStructureExportsLatex() throws {
        let numeratorSlot = UUID()
        let denominatorSlot = UUID()
        let exponentSlot = UUID()
        let numerator = MathNode.sequence(id: UUID(), children: [
            .slot(id: numeratorSlot, text: "x"),
            .superscript(
                id: UUID(),
                exponent: .sequence(id: UUID(), children: [.slot(id: exponentSlot, text: "2")])
            ),
            .slot(id: UUID(), text: "+1")
        ])
        let denominator = MathNode.sequence(id: UUID(), children: [
            .slot(id: denominatorSlot, text: "x-2")
        ])
        let root = MathNode.sequence(id: UUID(), children: [
            .slot(id: UUID(), text: ""),
            .fraction(id: UUID(), numerator: numerator, denominator: denominator),
            .slot(id: UUID(), text: "")
        ])
        try expect(root.latex == "\\frac{x^{2}+1}{x-2}", "嵌套结构 LaTeX")
    }

    private static func commonSymbolsExportAsLatexCommands() throws {
        let root = MathNode.sequence(id: UUID(), children: [
            .slot(id: UUID(), text: "α≤π")
        ])
        try expect(root.latex == "\\alpha \\le \\pi ", "常用符号转换")
    }

    private static func insertionPreservesExistingTextAndCreatesSlots() throws {
        let selected = UUID()
        let inner = UUID()
        let trailing = UUID()
        let root = MathNode.sequence(id: UUID(), children: [.slot(id: selected, text: "x")])
        let power = MathNode.superscript(
            id: UUID(),
            exponent: .sequence(id: UUID(), children: [.slot(id: inner, text: "2")])
        )
        let result = root.inserting(after: selected, node: power, trailingSlotID: trailing)
        try expect(result.latex == "x^{2}", "结构插入内容")
        try expect(result.slotIDs == [selected, inner, trailing], "结构插入 slot 顺序")
    }

    private static func slotInsertionAddsExactlyOneEditableSlot() throws {
        let selected = UUID()
        let added = UUID()
        let root = MathNode.sequence(id: UUID(), children: [.slot(id: selected, text: "12")])
        let result = root.insertingSlot(after: selected, newSlotID: added)
        try expect(result.slotIDs == [selected, added], "新增框数量与顺序")
        try expect(result.latex == "12", "新增空框不改变输出")
    }

    private static func outputFormatsRenderExpectedText() throws {
        let root = MathNode.sequence(id: UUID(), children: [
            .slot(id: UUID(), text: "x"),
            .superscript(
                id: UUID(),
                exponent: .sequence(id: UUID(), children: [.slot(id: UUID(), text: "2")])
            )
        ])
        try expect(root.plainText == "x²", "纯文本上标")
        try expect(
            OutputFormat.markdownInline.render(latex: root.latex, plainText: root.plainText) == "$x^{2}$",
            "Markdown 行内输出"
        )
        try expect(
            OutputFormat.markdownBlock.render(latex: root.latex, plainText: root.plainText) == "$$\nx^{2}\n$$",
            "Markdown 块输出"
        )
    }

    private static func symbolUsageOrdersFrequentAndRecent() throws {
        var usage = SymbolUsageState()
        usage.record("π")
        usage.record("≤")
        usage.record("π")
        usage.record(",")
        try expect(usage.frequent.first == "π", "常用符号按次数排序")
        try expect(usage.recent == [",", "π", "≤"], "最近符号按时间去重排序")
    }

    private static func newSlotReceivesSymbolWithoutChangingPreviousSlot() throws {
        let previous = UUID()
        let added = UUID()
        let root = MathNode.sequence(id: UUID(), children: [.slot(id: previous, text: "x")])
        let withSlot = root.insertingSlot(after: previous, newSlotID: added)
        let withComma = withSlot.updatingSlot(added, text: ",")
        try expect(withComma.text(for: previous) == "x", "新增框符号不回写上一个框")
        try expect(withComma.text(for: added) == ",", "新增框接收逗号")
    }

    private static func functionAndDerivativeTemplatesExportLatex() throws {
        let argument = UUID()
        let root = MathNode.sequence(id: UUID(), children: [
            .function(
                id: UUID(),
                name: "sin",
                argument: .sequence(id: UUID(), children: [.slot(id: argument, text: "x")])
            ),
            .slot(id: UUID(), text: "′")
        ])
        try expect(
            root.latex == "\\sin \\left(x\\right)'",
            "函数参数框与导数符号 LaTeX"
        )
        try expect(root.slotIDs.first == argument, "函数参数保持可编辑")
    }

    private static func limitsOperatorExportsLatexAndPlainText() throws {
        let upper = UUID()
        let lower = UUID()
        let root = MathNode.sequence(id: UUID(), children: [
            .limitsOperator(
                id: UUID(),
                name: "Σ",
                upper: .sequence(id: UUID(), children: [.slot(id: upper, text: "n")]),
                lower: .sequence(id: UUID(), children: [.slot(id: lower, text: "i=1")])
            ),
            .slot(id: UUID(), text: "x")
        ])
        try expect(
            root.latex == "\\sum _{i=1}^{n}x",
            "求和上下限 LaTeX"
        )
        try expect(
            root.plainText == "Σᵢ₌₁ⁿx",
            "求和上下限纯文本"
        )
        try expect(
            root.slotIDs.count == 3 && root.slotIDs[0] == lower && root.slotIDs[1] == upper,
            "求和上下限 slot 顺序"
        )

        let logRoot = MathNode.sequence(id: UUID(), children: [
            .limitsOperator(
                id: UUID(),
                name: "log",
                upper: .sequence(id: UUID(), children: [.slot(id: UUID(), text: "")]),
                lower: .sequence(id: UUID(), children: [.slot(id: UUID(), text: "a")])
            ),
            .slot(id: UUID(), text: "x")
        ])
        try expect(
            logRoot.latex == "\\log _{a}x",
            "log 底数 LaTeX"
        )
    }

    private static func limitsOperatorBlankLimitsAreOmitted() throws {
        let upper = UUID()
        let lower = UUID()
        let root = MathNode.sequence(id: UUID(), children: [
            .limitsOperator(
                id: UUID(),
                name: "lim",
                upper: .sequence(id: UUID(), children: [.slot(id: upper, text: "")]),
                lower: .sequence(id: UUID(), children: [.slot(id: lower, text: "x→0")])
            )
        ])
        try expect(
            root.latex.trimmingCharacters(in: .whitespacesAndNewlines) == "\\lim _{x\\to 0}",
            "lim 下极限 LaTeX"
        )
        try expect(
            root.plainText == "lim_(x→0)",
            "lim 纯文本下极限"
        )
    }

    private static func trigFunctionsExportAsLatexCommands() throws {
        let argument = UUID()
        let root = MathNode.sequence(id: UUID(), children: [
            .function(
                id: UUID(),
                name: "cot",
                argument: .sequence(id: UUID(), children: [.slot(id: argument, text: "x")])
            ),
            .slot(id: UUID(), text: "+")
        ])
        try expect(
            root.latex == "\\cot \\left(x\\right)+",
            "cot 函数 LaTeX"
        )
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ name: String) throws {
        checks += 1
        guard condition() else { throw SelfTestError.failed(name) }
    }
}

private enum SelfTestError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case let .failed(name): "自检失败：\(name)"
        }
    }
}

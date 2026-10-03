import SwiftUI

struct ContentView: View {
    @ObservedObject var model: EditorModel
    @State private var showingHistory = false
    @State private var formulaScale = 1.0
    @State private var paletteTab = "常用"

    private let symbols = [
        "±", "≠", "≤", "≥", "∞", "π", "θ", "α", "β", "Δ",
        "∈", "∪", "∩", "→", "×", "÷", "·", "=", ",",
        "(", ")", "[", "]", "′", "″"
    ]

    private let trigFunctions = [
        "sin", "cos", "tan", "cot", "sec", "csc",
        "arcsin", "arccos", "arctan"
    ]

    private let limitsOperators = [
        "Σ", "∫", "lim", "log", "ln", "lg"
    ]

    private let mouseInputs = [
        "1", "2", "3", "+",
        "4", "5", "6", "−",
        "7", "8", "9", "×",
        "0", ".", "x", "y"
    ]

    private let functionInputs = [
        "f", "g"
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                palette
                Divider()
                editor
            }
            Divider()
            outputBar
        }
        .frame(minWidth: 880, minHeight: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showingHistory) {
            HistoryView(model: model)
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "function")
                .foregroundStyle(Color.accentColor)
            Text("MathPad").font(.headline)
            Text("鼠标优先的公式输入器")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button { showingHistory = true } label: {
                Label("历史", systemImage: "clock.arrow.circlepath")
            }
            Button("清空", systemImage: "trash") { model.clear() }
                .keyboardShortcut("k", modifiers: [.command])
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
    }

    private var palette: some View {
        VStack(spacing: 0) {
            quickSymbols
            Divider()
            Picker("符号分类", selection: $paletteTab) {
                Text("常用").tag("常用")
                Text("结构").tag("结构")
                Text("数字").tag("数字")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 14)
            .padding(.top, 12)
            ScrollView {
                VStack(alignment: .leading, spacing: 9) {
                if paletteTab == "结构" {
                Text("数学结构")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(StructureKind.allCases) { kind in
                        Button(kind.rawValue) { model.insertStructure(kind) }
                            .buttonStyle(PaletteButtonStyle())
                    }
                }
                }

                if paletteTab == "结构" {
                Text("带上下限结构")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(limitsOperators, id: \.self) { name in
                        Button(name) { model.insertLimitsOperator(name) }
                            .buttonStyle(PaletteButtonStyle())
                    }
                }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    Button("新增框", systemImage: "rectangle.badge.plus") {
                        model.addSlotAfterSelection()
                    }
                    .buttonStyle(PaletteButtonStyle())
                    .help("在当前编辑框后增加一个空框")
                    Button("退格", systemImage: "delete.left") {
                        model.deleteBackward()
                    }
                    .buttonStyle(PaletteButtonStyle())
                    Menu {
                        ForEach(functionInputs, id: \.self) { name in
                            Button("\(name)(□)") { model.insertFunction(name) }
                        }
                    } label: {
                        Label("函数", systemImage: "function")
                    }
                    .menuStyle(.button)
                    .buttonStyle(PaletteButtonStyle())
                    Button {
                        model.insertSymbol("′")
                    } label: {
                        Label("求导 ′", systemImage: "textformat.superscript")
                    }
                    .buttonStyle(PaletteButtonStyle())
                }

                if paletteTab == "数字" {
                Text("数字与输入")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 6) {
                    ForEach(mouseInputs, id: \.self) { value in
                        Button(value) { model.insertInput(value) }
                            .buttonStyle(SymbolButtonStyle())
                    }
                }
                }

                if paletteTab == "常用" {
                Text("常用符号 · 三角函数")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 6) {
                    ForEach(trigFunctions, id: \.self) { name in
                        Button(name) { model.insertFunction(name) }
                            .buttonStyle(TrigButtonStyle())
                            .help("插入 \(name)(□)，点击参数框输入")
                    }
                }

                Text("常用符号")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 5) {
                    ForEach(symbols, id: \.self) { symbol in
                        Button(symbol) { model.insertSymbol(symbol) }
                            .buttonStyle(SymbolButtonStyle())
                    }
                }
                }
                Spacer(minLength: 8)
                Text("Tab 切换编辑框\n⇧Tab 返回上一个")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                }
                .padding(14)
            }
        }
        .frame(width: 330)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }

    private var quickSymbols: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("快捷符号", systemImage: "clock.badge.checkmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            quickSymbolRow(title: "常用", symbols: model.frequentSymbols)
            quickSymbolRow(title: "最近", symbols: model.recentSymbols)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func quickSymbolRow(title: String, symbols: [String]) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 26, alignment: .leading)
            if symbols.isEmpty {
                Text("使用符号后显示")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(spacing: 6) {
                        ForEach(symbols, id: \.self) { symbol in
                            Button(symbol) { model.insertSymbol(symbol) }
                                .buttonStyle(QuickSymbolButtonStyle())
                                .help("插入 \(symbol)")
                        }
                    }
                }
            }
        }
        .frame(height: 34)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("公式").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Button { model.moveSlot(backward: true) } label: {
                    Image(systemName: "chevron.left")
                }.help("上一个编辑框 · Shift+Tab")
                Button { model.moveSlot(backward: false) } label: {
                    Image(systemName: "chevron.right")
                }.help("下一个编辑框 · Tab")
                Divider().frame(height: 16)
                Button { formulaScale = max(0.75, formulaScale - 0.25) } label: {
                    Image(systemName: "minus.magnifyingglass")
                }.disabled(formulaScale <= 0.75).help("缩小公式")
                Text("\(Int(formulaScale * 100))%")
                    .font(.caption.monospacedDigit()).frame(width: 40)
                Button { formulaScale = min(2, formulaScale + 0.25) } label: {
                    Image(systemName: "plus.magnifyingglass")
                }.disabled(formulaScale >= 2).help("放大公式")
            }
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    FormulaView(node: model.root, model: model)
                        .environment(\.formulaScale, formulaScale)
                        .padding(32)
                        .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.18))
            )
            Text("点击蓝色框输入 · Tab 切换 · Shift+Tab 返回")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }

    private var outputBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("输出格式").font(.caption.weight(.semibold))
                Picker("输出格式", selection: $model.selectedOutputFormat) {
                    ForEach(OutputFormat.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 150)
                Spacer()
                Text("Enter 复制并隐藏 · Esc 隐藏")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                ScrollView {
                    Text(model.latex.isEmpty ? "公式的输出会显示在这里" : model.formattedOutput)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(model.latex.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 58)
                Button("复制并隐藏", systemImage: "doc.on.doc") {
                    _ = model.copyCurrentAndHide()
                }
                .buttonStyle(.borderedProminent)
                .lineLimit(1)
                .fixedSize()
                .disabled(model.latex.isEmpty)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 9).fill(Color.secondary.opacity(0.07)))
        }
        .padding(14)
    }
}

private struct PaletteButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(configuration.isPressed ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.09))
            )
    }
}

private struct SymbolButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, design: .serif))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .frame(maxWidth: .infinity, minHeight: 30)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
            )
    }
}

private struct QuickSymbolButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, design: .serif))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 8)
            .frame(minWidth: 30, minHeight: 28)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.09))
            )
    }
}

private struct TrigButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium, design: .serif))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .frame(maxWidth: .infinity, minHeight: 30)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
            )
    }
}

private struct HistoryView: View {
    @ObservedObject var model: EditorModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("历史记录").font(.title3.weight(.semibold))
                Spacer()
                Button("清除") { model.deleteHistory() }
                    .disabled(model.history.isEmpty)
                Button("完成") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
            Divider()
            if model.history.isEmpty {
                ContentUnavailableView("还没有历史记录", systemImage: "clock", description: Text("复制过的公式会保存在这里。"))
            } else {
                List(model.history) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(entry.latex).font(.system(.body, design: .monospaced)).lineLimit(2)
                            if let formatName = entry.formatName {
                                Text(formatName).font(.caption2).foregroundStyle(.tertiary)
                            }
                            Text(entry.createdAt, style: .relative).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("复制") { model.copyHistory(entry) }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(width: 560, height: 380)
    }
}

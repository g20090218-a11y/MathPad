import SwiftUI

private struct FormulaScaleKey: EnvironmentKey {
    static let defaultValue = 1.0
}

extension EnvironmentValues {
    var formulaScale: Double {
        get { self[FormulaScaleKey.self] }
        set { self[FormulaScaleKey.self] = newValue }
    }
}

struct FormulaView: View {
    let node: MathNode
    @ObservedObject var model: EditorModel
    @Environment(\.formulaScale) private var scale

    var body: some View {
        nodeBody
            .font(.system(size: 24 * scale, design: .serif))
            .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private var nodeBody: some View {
        switch node {
        case let .sequence(_, children):
            HStack(alignment: .center, spacing: 2) {
                ForEach(children, id: \.id) { child in
                    FormulaView(node: child, model: model)
                }
            }
        case let .slot(id, text):
            SlotField(id: id, text: text, model: model)
        case let .fraction(_, numerator, denominator):
            VStack(spacing: 2) {
                FormulaView(node: numerator, model: model)
                Rectangle().frame(height: 1.5).foregroundStyle(.primary)
                FormulaView(node: denominator, model: model)
            }
            .padding(.horizontal, 3)
        case let .radical(_, radicand):
            HStack(spacing: 0) {
                Text("√").font(.system(size: 30 * scale, weight: .light, design: .serif))
                FormulaView(node: radicand, model: model)
                    .padding(.top, 3)
                    .overlay(alignment: .top) { Rectangle().frame(height: 1) }
            }
        case let .superscript(_, exponent):
            FormulaView(node: exponent, model: model)
                .environment(\.formulaScale, scale * 0.78)
                .padding(.bottom, 18 * scale)
        case let .subscriptNode(_, subscriptValue):
            FormulaView(node: subscriptValue, model: model)
                .environment(\.formulaScale, scale * 0.78)
                .padding(.top, 18 * scale)
        case let .absolute(_, content):
            HStack(spacing: 3) {
                Text("|")
                FormulaView(node: content, model: model)
                Text("|")
            }
        case let .parentheses(_, content):
            HStack(spacing: 3) {
                Text("(")
                FormulaView(node: content, model: model)
                Text(")")
            }
        case let .function(_, name, argument):
            HStack(spacing: 3) {
                Text("\(name)(")
                FormulaView(node: argument, model: model)
                Text(")")
            }
        case let .limitsOperator(_, name, upper, lower):
            limitsBody(name: name, upper: upper, lower: lower)
        }
    }

    private func limitsBody(name: String, upper: MathNode, lower: MathNode) -> some View {
        return HStack(spacing: 3) {
            if ["log", "ln", "lg"].contains(name) {
                Text(name)
                VStack(spacing: 4) {
                    FormulaView(node: upper, model: model)
                        .environment(\.formulaScale, scale * 0.7)
                    FormulaView(node: lower, model: model)
                        .environment(\.formulaScale, scale * 0.7)
                }
            } else {
                VStack(spacing: 4) {
                    FormulaView(node: upper, model: model)
                        .environment(\.formulaScale, scale * 0.7)
                    Text(name)
                        .font(.system(size: name.count == 1 ? 34 * scale : 24 * scale, design: .serif))
                    FormulaView(node: lower, model: model)
                        .environment(\.formulaScale, scale * 0.7)
                }
            }
        }
        .padding(.horizontal, 6)
        .fixedSize()
    }
}

private struct SlotField: View {
    let id: UUID
    let text: String
    @ObservedObject var model: EditorModel
    @Environment(\.formulaScale) private var scale

    var body: some View {
        SlotTextField(id: id, text: text, model: model, fontSize: 24 * scale)
        .frame(width: max(30 * scale, (text as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 24 * scale)]).width + 12),
               height: 29 * scale)
        .padding(.horizontal, 3)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(model.activeSlotID == id ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(model.activeSlotID == id ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: 1)
        )
    }
}

private struct SlotTextField: NSViewRepresentable {
    let id: UUID
    let text: String
    let model: EditorModel
    let fontSize: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(id: id, model: model)
    }

    func makeNSView(context: Context) -> SelectableTextField {
        let field = SelectableTextField()
        field.delegate = context.coordinator
        field.onExplicitClick = { [weak model] in
            model?.selectSlot(id)
        }
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.alignment = .center
        field.font = .systemFont(ofSize: fontSize)
        field.placeholderString = "□"
        field.setAccessibilityLabel("公式编辑框")
        field.stringValue = text
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        SlotFocusRegistry.shared.register(field, for: id)
        return field
    }

    func updateNSView(_ field: SelectableTextField, context: Context) {
        field.font = .systemFont(ofSize: fontSize)
        context.coordinator.id = id
        field.onExplicitClick = { [weak model] in
            model?.selectSlot(id)
        }
        if field.stringValue != text {
            field.stringValue = text
            if let editor = field.currentEditor() as? NSTextView {
                editor.string = text
                editor.setSelectedRange(NSRange(location: text.utf16.count, length: 0))
            }
        }
        guard model.activeSlotID == id, field.currentEditor() == nil else { return }
        DispatchQueue.main.async { [weak field, weak model] in
            guard model?.activeSlotID == id, let field,
                  field.window?.firstResponder !== field.currentEditor() else { return }
            field.window?.makeFirstResponder(field)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var id: UUID
        let model: EditorModel

        init(id: UUID, model: EditorModel) {
            self.id = id
            self.model = model
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            model.updateSlot(id: id, text: field.stringValue)
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                model.moveSlot(backward: false)
                return true
            }
            if commandSelector == #selector(NSResponder.insertBacktab(_:)) {
                model.moveSlot(backward: true)
                return true
            }
            return false
        }
    }
}

private final class SelectableTextField: NSTextField {
    var onExplicitClick: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onExplicitClick?()
        super.mouseDown(with: event)
    }
}

@MainActor
final class SlotFocusRegistry {
    static let shared = SlotFocusRegistry()

    private final class WeakField {
        weak var value: NSTextField?
        init(_ value: NSTextField) { self.value = value }
    }

    private var fields: [UUID: WeakField] = [:]

    func register(_ field: NSTextField, for id: UUID) {
        fields = fields.filter { $0.value.value != nil }
        fields[id] = WeakField(field)
    }

    func focus(_ id: UUID) {
        guard let field = fields[id]?.value else { return }
        field.window?.makeFirstResponder(field)
    }

    func inserting(_ value: String, in id: UUID) -> String? {
        guard let field = fields[id]?.value, let editor = field.currentEditor() as? NSTextView else { return nil }
        let range = editor.selectedRange()
        let current = editor.string as NSString
        guard range.location != NSNotFound, NSMaxRange(range) <= current.length else { return nil }
        let updated = current.replacingCharacters(in: range, with: value)
        editor.string = updated
        editor.setSelectedRange(NSRange(location: range.location + value.utf16.count, length: 0))
        field.stringValue = updated
        return updated
    }
}

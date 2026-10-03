# 参与开发

欢迎提交 Issue 和 Pull Request。请说明 macOS 版本、复现步骤以及预期行为。

MathPad 使用 SwiftUI、AppKit 和 Carbon，无第三方依赖。请保持离线运行、递归 AST、可点击参数框与鼠标优先的交互方式。

## 构建

需要 macOS 14 或更新版本，以及 Swift 6.2 或更新版本的工具链。

```sh
MATHPAD_SKIP_SELF_TEST=1 zsh package_app.sh
open ../MathPad.app
```

内置自检可按需运行：

```sh
../MathPad.app/Contents/MacOS/MathPad --self-test
```

## 主要文件

- `MathNode.swift`：递归节点、编辑操作和输出转换。
- `EditorModel.swift`：选中框、插入操作、历史与快捷符号。
- `FormulaView.swift`：结构布局和原生输入框。
- `ContentView.swift`：左侧面板、公式区和输出区。
- `AppDelegate.swift` / `GlobalHotKey.swift`：窗口生命周期和全局快捷键。

请在 Pull Request 中说明修改内容与实际完成的验证。未进行的验证请明确标注。

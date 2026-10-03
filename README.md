# MathPad

<img src="Resources/AppIcon.png" alt="MathPad icon" width="96" />

MathPad 是一个离线、原生的 macOS 数学公式输入器。按 `⌥Space` 呼出，使用鼠标插入结构、键盘填写内容，按 Enter 复制所选格式的输出并隐藏窗口，默认输出为纯文本。

原生 SwiftUI / AppKit · macOS 14+ · 无第三方依赖 · MIT License

## 当前 MVP

- 递归结构化 AST（不是把编辑状态保存成一段 LaTeX 字符串）
- 分数、根号、上标、下标、绝对值、括号
- 带上下限的大运算符：Σ、∫、lim、log、ln、lg 点击后出现可编辑的上下小框，如 `\sum_{i=1}^{n}`、`\lim_{x \to 0}`、`\log_{a}`
- 三角函数 `sin/cos/tan/cot/sec/csc/arcsin/arccos/arctan` 直接放入“三角函数”区，点击插入 `sin(□)` 结构
- 常用高中数学符号与 LaTeX 转换
- 区间专用的 `(`、`)`、`[`、`]` 独立符号按钮
- 函数会生成可编辑的参数框，例如 `f(□)`；求导按钮只插入独立的 `′` 符号
- 数字、基础运算符、变量和退格按钮，可纯鼠标输入
- “新增框”可在当前选中 slot 后插入一个新 slot
- 顶部固定快捷符号栏：常用符号按次数排序，最近符号按使用时间排序并持久保存
- 330 点宽的左栏，按“常用 / 结构 / 数字”切换；操作按钮分两列，长名称保持单行
- 旧版快捷函数自动转为可编辑结构；函数、运算符会记录到常用/最近栏
- 公式按实际字体宽度扩展；上下限参与布局，避免嵌套时重叠
- 编辑框前后移动按钮、75%–200% 公式缩放、可滚动查看完整输出
- 点击符号或数字时优先插入当前光标位置，支持替换选中文字
- 点击编辑 slot，`Tab` / `Shift+Tab` 前后移动
- LaTeX、纯文本、Markdown 行内、Markdown 块四种输出格式
- 默认使用纯文本输出；`Enter` 复制、清空并隐藏，`Escape` 仅隐藏并保留内容
- `⌥Space` 全局呼出/隐藏
- 最多 30 条本地历史记录
- Dock 常驻，关闭窗口不退出
- 简约分式结构应用图标（完整 macOS 多分辨率图标集）

## 构建与测试

系统需要 macOS 14 或更高版本，以及 Swift 6.2 命令行工具。

```sh
git clone https://github.com/g20090218-a11y/MathPad.git
cd MathPad
MATHPAD_SKIP_SELF_TEST=1 ./package_app.sh
open ../MathPad.app
```

`package_app.sh` 会先构建发布版本并执行内置核心自检，然后在输出目录生成标准的 `MathPad.app`。应用完全离线运行，不包含第三方依赖。

只编译打包、不执行自检：`MATHPAD_SKIP_SELF_TEST=1 ./package_app.sh`。

## 操作说明

1. 在当前蓝色 slot 中输入数字或字母。
2. 点击左侧结构按钮，结构会插入到当前 slot 后，焦点进入结构内部。
3. 使用 `Tab` 或 `Shift+Tab` 在所有 slot 之间移动。
4. 在底部选择输出格式，并查看实际将要复制的内容。
5. 按 Enter 完成复制并隐藏窗口，之后在目标应用中按 `⌘V`。

提示：`⌥Space` 若被其他应用占用，系统只会允许其中一个应用响应。MVP 暂未提供快捷键修改界面。

## 状态与限制

当前版本为 0.7.0，仍处于 MVP 阶段。发布前完成了本机编译、应用签名检查和界面查看，没有完成系统性的交互验证。已在 Apple Silicon Mac 上构建；其他设备需要自行编译验证。

构建脚本生成的应用使用本地临时签名，未经过 Apple 公证。需要正式发行签名时，可使用自己的 Developer ID 证书。

历史记录和符号使用频次保存在本机 UserDefaults 中，不上传网络。

## 开源许可

源码和本仓库应用图标采用 [MIT License](LICENSE)。开发参与说明见 [CONTRIBUTING.md](CONTRIBUTING.md)。

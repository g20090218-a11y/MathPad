import AppKit

if CommandLine.arguments.contains("--self-test") {
    do {
        let count = try SelfTest.run()
        print("MathPad self-test: \(count) checks passed")
        exit(EXIT_SUCCESS)
    } catch {
        fputs("\(error.localizedDescription)\n", stderr)
        exit(EXIT_FAILURE)
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()

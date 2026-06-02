import Foundation

if CommandLine.arguments.contains("--uninstall-helper") {
    uninstallHelper()
    exit(0)
}

do {
    try installHelper()
    exit(0)
} catch {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(1)
}

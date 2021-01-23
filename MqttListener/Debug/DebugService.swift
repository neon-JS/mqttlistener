import Foundation

class DebugService
{
    public static var debugLogsActive = false

    private static let FormattingErrorBold   = "\u{001B}[1;31m"
    private static let FormattingErrorNormal = "\u{001B}[0;31m"
    private static let FormattingDebugBold   = "\u{001B}[1;33m"
    private static let FormattingDebugNormal = "\u{001B}[0;33m"
    private static let FormattingReset       = "\u{001B}[0m"

    public static func printBinaryData(_ data: [Int])
    {
        data.forEach { (value) in
            var binaryValue = String(value, radix: 2)

            for _ in binaryValue.count..<8 {
                binaryValue = "0" + binaryValue
            }

            self.log("0b" + binaryValue, showDebugLabel: false)
        }
    }

    public static func log(_ message: String, showDebugLabel: Bool = true)
    {
        if (!self.debugLogsActive) {
            return
        }

        if (showDebugLabel) {
            print(self.FormattingDebugBold + "DEBUG: ", terminator: "")
        }

        print(self.FormattingDebugNormal + message + self.FormattingReset)
    }

    public static func error(_ message: String)
    {
        print(self.FormattingErrorBold + "ERROR: " + self.FormattingErrorNormal + message + self.FormattingReset)
    }
}

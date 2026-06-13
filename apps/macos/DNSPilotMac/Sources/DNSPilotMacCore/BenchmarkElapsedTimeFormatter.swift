import Foundation

public enum BenchmarkElapsedTimeFormatter {
    public static func label(milliseconds: Int) -> String {
        let clampedMilliseconds = max(0, milliseconds)
        guard clampedMilliseconds >= 1_000 else {
            return "\(clampedMilliseconds) ms"
        }

        let seconds = Double(clampedMilliseconds) / 1_000
        return String(format: "%.1f s", seconds)
    }
}

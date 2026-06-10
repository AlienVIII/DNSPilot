import SwiftUI

public enum DNSPilotDesign {
    public enum Spacing {
        public static let controlGap: CGFloat = 6
        public static let panel: CGFloat = 18
        public static let row: CGFloat = 10
    }

    public enum Radius {
        public static let card: CGFloat = 8
        public static let control: CGFloat = 6
    }

    public enum Palette {
        public static let background = Color(nsColor: .windowBackgroundColor)
        public static let panel = Color(nsColor: .controlBackgroundColor)
        public static let accent = Color(red: 0.08, green: 0.36, blue: 0.56)
        public static let warning = Color(red: 0.72, green: 0.36, blue: 0.10)
    }
}

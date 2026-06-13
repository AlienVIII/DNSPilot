import AppKit
import SwiftUI

public struct DNSPilotMultilineTextInput: NSViewRepresentable {
    @Binding private var text: String
    private let isEditable: Bool

    public init(text: Binding<String>, isEditable: Bool = true) {
        _text = text
        self.isEditable = isEditable
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder

        let textView = Self.makeConfiguredTextView(initialText: text, isEditable: isEditable)
        textView.delegate = context.coordinator
        scrollView.documentView = textView

        return scrollView
    }

    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }
        textView.delegate = context.coordinator
        textView.isEditable = isEditable
        textView.textColor = isEditable ? .labelColor : .disabledControlTextColor
        if textView.string != text {
            textView.string = text
        }
    }

    static func makeConfiguredTextView(initialText: String, isEditable: Bool = true) -> NSTextView {
        let textView = NSTextView()
        textView.string = initialText
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.textColor = isEditable ? .labelColor : .disabledControlTextColor
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.textContainerInset = NSSize(
            width: DNSPilotDesign.Spacing.controlGap,
            height: DNSPilotDesign.Spacing.controlGap
        )
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        return textView
    }

    public final class Coordinator: NSObject, NSTextViewDelegate {
        private let text: Binding<String>

        public init(text: Binding<String>) {
            self.text = text
        }

        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }
            text.wrappedValue = textView.string
        }
    }
}

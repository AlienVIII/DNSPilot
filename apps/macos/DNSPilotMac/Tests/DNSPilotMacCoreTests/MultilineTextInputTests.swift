import AppKit
import SwiftUI
import XCTest
@testable import DNSPilotMacCore

@MainActor
final class MultilineTextInputTests: XCTestCase {
    func testCoordinatorWritesTextViewChangesToBinding() {
        let box = TextBindingBox("")
        let coordinator = DNSPilotMultilineTextInput.Coordinator(text: box.binding)
        let textView = NSTextView()

        textView.string = "portal.azure.com"
        coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))

        XCTAssertEqual(box.value, "portal.azure.com")
    }

    func testMakeNSViewCreatesEditablePlainTextView() {
        let textView = DNSPilotMultilineTextInput.makeConfiguredTextView(initialText: "github.com")

        XCTAssertEqual(textView.string, "github.com")
        XCTAssertEqual(textView.isEditable, true)
        XCTAssertEqual(textView.isSelectable, true)
        XCTAssertEqual(textView.isRichText, false)
        XCTAssertEqual(textView.allowsUndo, true)
    }
}

@MainActor
private final class TextBindingBox {
    var value: String

    init(_ value: String) {
        self.value = value
    }

    var binding: Binding<String> {
        Binding(
            get: { self.value },
            set: { self.value = $0 }
        )
    }
}

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

    func testInputHitTestingReachesNativeTextViewThroughChrome() {
        let box = TextBindingBox("")
        let view = DNSPilotMultilineTextInput(text: box.binding)
            .frame(width: 320, height: 88)
            .background(.background, in: RoundedRectangle(cornerRadius: DNSPilotDesign.Radius.control))
            .overlay {
                RoundedRectangle(cornerRadius: DNSPilotDesign.Radius.control)
                    .stroke(.separator.opacity(0.5))
        }
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 88)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 88),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))

        let hitView = hostingView.hitTest(NSPoint(x: 160, y: 44))

        window.close()
        XCTAssertTrue(
            hitView is NSTextView || hitView?.superview is NSTextView,
            "hitView=\(String(describing: hitView.map { type(of: $0) })), superview=\(String(describing: hitView?.superview.map { type(of: $0) }))"
        )
    }

    func testMountedInputRoutesKeyDownIntoBinding() {
        let box = TextBindingBox("")
        let mounted = mountInput(text: box.binding)
        guard let textView = mounted.hostingView.firstDescendant(ofType: NSTextView.self) else {
            XCTFail("Expected mounted NSTextView")
            return
        }
        mounted.window.makeFirstResponder(textView)
        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: NSPoint(x: 160, y: 44),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: mounted.window.windowNumber,
            context: nil,
            characters: "g",
            charactersIgnoringModifiers: "g",
            isARepeat: false,
            keyCode: 5
        )

        if let event {
            textView.keyDown(with: event)
        }

        mounted.window.close()
        XCTAssertEqual(box.value, "g")
    }

    private func mountInput(text: Binding<String>) -> (window: NSWindow, hostingView: NSHostingView<some View>) {
        let view = DNSPilotMultilineTextInput(text: text)
            .frame(width: 320, height: 88)
            .background(.background, in: RoundedRectangle(cornerRadius: DNSPilotDesign.Radius.control))
            .overlay {
                RoundedRectangle(cornerRadius: DNSPilotDesign.Radius.control)
                    .stroke(.separator.opacity(0.5))
            }
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 88)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 88),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        return (window, hostingView)
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

private extension NSView {
    func firstDescendant<T: NSView>(ofType type: T.Type) -> T? {
        if let match = self as? T {
            return match
        }
        for subview in subviews {
            if let match = subview.firstDescendant(ofType: type) {
                return match
            }
        }
        return nil
    }
}

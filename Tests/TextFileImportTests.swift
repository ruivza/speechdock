import AppKit
import XCTest
@testable import SpeechDock

@MainActor
final class TextFileImportTests: XCTestCase {
    private func fixture(_ data: Data, extension ext: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
        try data.write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    func testNativeSTTAudioDropStillPostsNotificationWithoutInsertingPath() throws {
        let url = try fixture(Data(), extension: "wav")
        let editor = FocusableTextView()
        editor.handlesAudioFileDrop = true
        editor.string = "Existing transcript"
        let drag = FileDrag(url: url)
        var received: URL?
        let observer = NotificationCenter.default.addObserver(forName: .audioFileDropped, object: nil, queue: .main) {
            received = $0.object as? URL
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        XCTAssertTrue(editor.performDragOperation(drag))
        XCTAssertEqual(received, url)
        XCTAssertEqual(editor.string, "Existing transcript")
    }

    func testNativeTTSFileDropImportsContents() throws {
        let url = try fixture(Data("File contents".utf8), extension: "txt")
        let editor = FocusableTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        editor.handlesTextFileDrop = true
        let drag = FileDrag(url: url)
        XCTAssertEqual(editor.draggingEntered(drag), .copy)
        XCTAssertTrue(editor.performDragOperation(drag))
        XCTAssertEqual(editor.string, "File contents")
    }

    func testUTF8FormatsAndBOM() throws {
        for ext in ["txt", "MD", "text"] {
            let url = try fixture(Data("\u{FEFF}日本語 😀\ntext".utf8), extension: ext)
            XCTAssertEqual(try TextFileImport.read(url), "日本語 😀\ntext")
        }
    }

    func testRTFImportsPlainText() throws {
        let text = NSAttributedString(string: "日本語 and text")
        let data = try text.data(from: NSRange(location: 0, length: text.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        XCTAssertEqual(try TextFileImport.read(fixture(data, extension: "rtf")), text.string)
    }

    func testInvalidEncodingBinaryUnsupportedAndLargeFilesAreRejected() throws {
        for (data, ext) in [(Data([0xff, 0xfe, 0x41]), "txt"), (Data([0, 65]), "txt"), (Data("path".utf8), "pdf"), (Data(repeating: 65, count: TextFileImport.maximumBytes + 1), "txt")] {
            XCTAssertThrowsError(try TextFileImport.read(fixture(data, extension: ext)))
        }
    }

    func testEmptyFileIsValid() throws {
        XCTAssertEqual(try TextFileImport.read(fixture(Data(), extension: "txt")), "")
    }

    func testInsertionPreservesExistingTextAndSupportsUndoRedo() throws {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 200), styleMask: .titled, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let editor = FocusableTextView(frame: window.contentView!.bounds)
        editor.isRichText = false
        editor.allowsUndo = true
        window.contentView = editor
        editor.string = "😀beforeafter"
        editor.setSelectedRange(NSRange(location: 0, length: 2))
        let url = try fixture(Data("INSERT".utf8), extension: "txt")
        let undo = try XCTUnwrap(editor.undoManager)
        undo.beginUndoGrouping()
        try editor.insertTextFiles([url], at: 8)
        undo.endUndoGrouping()
        XCTAssertEqual(editor.string, "😀beforeINSERTafter")
        undo.undo()
        XCTAssertEqual(editor.string, "😀beforeafter")
        undo.redo()
        XCTAssertEqual(editor.string, "😀beforeINSERTafter")
    }

    func testEmptyEditorAndFailedMultiFileImport() throws {
        let editor = FocusableTextView()
        let valid = try fixture(Data("Contents".utf8), extension: "txt")
        try editor.insertTextFiles([valid], at: 0)
        XCTAssertEqual(editor.string, "Contents")
        let invalid = try fixture(Data([0xff]), extension: "txt")
        XCTAssertThrowsError(try editor.insertTextFiles([valid, invalid], at: 2))
        XCTAssertEqual(editor.string, "Contents")
        editor.isEditable = false
        try editor.insertTextFiles([valid], at: 0)
        XCTAssertEqual(editor.string, "Contents")
    }
}

@MainActor
private final class FileDrag: NSObject, @preconcurrency NSDraggingInfo {
    var draggingDestinationWindow: NSWindow? { nil }
    var draggingSourceOperationMask: NSDragOperation { .copy }
    var draggingLocation: NSPoint { .zero }
    var draggedImageLocation: NSPoint { .zero }
    var draggedImage: NSImage? { nil }
    let draggingPasteboard = NSPasteboard.withUniqueName()
    var draggingSource: Any? { nil }
    var draggingSequenceNumber: Int { 1 }
    var draggingFormation: NSDraggingFormation = .none
    var animatesToDestination = false
    var numberOfValidItemsForDrop = 1
    var springLoadingHighlight: NSSpringLoadingHighlight { .none }
    init(url: URL) {
        super.init()
        draggingPasteboard.writeObjects([url as NSURL])
    }
    func slideDraggedImage(to screenPoint: NSPoint) {}
    override func namesOfPromisedFilesDropped(atDestination dropDestination: URL) -> [String]? { nil }
    func resetSpringLoading() {}
    func enumerateDraggingItems(options: NSDraggingItemEnumerationOptions, for view: NSView?, classes: [AnyClass], searchOptions: [NSPasteboard.ReadingOptionKey: Any], using block: (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void) {}
}

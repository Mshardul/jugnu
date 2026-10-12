import PDFKit
import XCTest
@testable import PDFToolsCore

final class PDFUnlockTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pdf-unlock-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func test_destination_avoidsExistingUnlockedCopy() throws {
        let source = directory.appendingPathComponent("Report.pdf")
        try Data("x".utf8).write(to: source)
        try Data("y".utf8).write(to: directory.appendingPathComponent("Report (unlocked).pdf"))
        let dest = PDFUnlock.destination(beside: source)
        XCTAssertEqual(dest.lastPathComponent, "Report (unlocked) 2.pdf")
    }

    func test_plainPDF_isLeftAlone() throws {
        let source = try writePDF(named: "Notes.pdf", userPassword: nil, ownerPassword: nil)
        XCTAssertThrowsError(try PDFUnlock.removePassword(from: source, password: nil)) { error in
            XCTAssertEqual(error as? PDFUnlockError, .notProtected)
        }
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: directory.appendingPathComponent("Notes (unlocked).pdf").path
        ))
    }

    func test_userPassword_writesUnlockedCopyBesideOriginal() throws {
        let source = try writePDF(named: "Report.pdf", userPassword: "secret", ownerPassword: "secret")
        let locked = PDFDocument(url: source)
        XCTAssertEqual(locked?.isLocked, true)

        XCTAssertThrowsError(try PDFUnlock.removePassword(from: source, password: nil)) { error in
            XCTAssertEqual(error as? PDFUnlockError, .needsPassword)
        }
        XCTAssertThrowsError(try PDFUnlock.removePassword(from: source, password: "nope")) { error in
            XCTAssertEqual(error as? PDFUnlockError, .wrongPassword)
        }
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: directory.appendingPathComponent("Report (unlocked).pdf").path
        ))

        let dest = try PDFUnlock.removePassword(from: source, password: "secret")
        XCTAssertEqual(dest.lastPathComponent, "Report (unlocked).pdf")
        let opened = PDFDocument(url: dest)
        XCTAssertEqual(opened?.isLocked, false)
        XCTAssertEqual(opened?.isEncrypted, false)
        XCTAssertEqual(opened?.pageCount, 1)
        XCTAssertEqual(PDFDocument(url: source)?.isLocked, true)
    }

    func test_ownerRestriction_writesUnlockedCopyWithoutPassword() throws {
        let source = try writePDF(named: "Owner.pdf", userPassword: nil, ownerPassword: "owner-secret")
        let opened = PDFDocument(url: source)
        XCTAssertEqual(opened?.isLocked, false)
        XCTAssertEqual(opened?.isEncrypted, true)
        let dest = try PDFUnlock.removePassword(from: source, password: nil)
        let copy = PDFDocument(url: dest)
        XCTAssertEqual(copy?.isEncrypted, false)
        XCTAssertEqual(copy?.isLocked, false)
    }

    func test_session_asksThenUnlocksWithSuppliedPassword() throws {
        let source = try writePDF(named: "Report.pdf", userPassword: "secret", ownerPassword: "secret")
        let state = directory.appendingPathComponent("state", isDirectory: true)
        let asked = PDFUnlockSession.run(files: [source], password: nil, stateDirectory: state)
        XCTAssertEqual(asked.ask, source)
        XCTAssertEqual(PendingUnlock.load(directory: state), [source])

        let wrong = PDFUnlockSession.run(files: [source], password: "nope", stateDirectory: state)
        XCTAssertTrue(wrong.wrongPassword)
        XCTAssertEqual(PendingUnlock.load(directory: state), [source])
        XCTAssertTrue(PDFUnlockReply.json(for: wrong).contains("That password didn’t open Report.pdf."))

        let done = PDFUnlockSession.run(
            files: PendingUnlock.load(directory: state),
            password: "secret",
            stateDirectory: state
        )
        XCTAssertEqual(done.saved.map(\.lastPathComponent), ["Report (unlocked).pdf"])
        XCTAssertNil(done.ask)
        XCTAssertTrue(PendingUnlock.load(directory: state).isEmpty)
        XCTAssertTrue(PDFUnlockReply.json(for: done).contains("Saved Report (unlocked).pdf next to the original."))
    }

    private func writePDF(named name: String, userPassword: String?, ownerPassword: String?) throws -> URL {
        let document = PDFDocument()
        document.insert(PDFPage(), at: 0)
        let url = directory.appendingPathComponent(name)
        var options: [PDFDocumentWriteOption: Any] = [:]
        if let userPassword {
            options[.userPasswordOption] = userPassword
        }
        if let ownerPassword {
            options[.ownerPasswordOption] = ownerPassword
        }
        if options.isEmpty {
            XCTAssertTrue(document.write(to: url))
        } else {
            XCTAssertTrue(document.write(to: url, withOptions: options))
        }
        return url
    }
}

@testable import JugnuCore
import XCTest

final class ConvertOutputTests: XCTestCase {
    private func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir
    }

    func testFirstNameIsPlain() throws {
        let dir = try tempDir()
        let url = try ConvertOutput.reserve(directory: dir, baseName: "report", ext: "csv")
        XCTAssertEqual(url.lastPathComponent, "report.csv")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testNeverOverwritesAndNumbersTheSibling() throws {
        let dir = try tempDir()
        try Data("keep me".utf8).write(to: dir.appendingPathComponent("report.csv"))
        let second = try ConvertOutput.reserve(directory: dir, baseName: "report", ext: "csv")
        let third = try ConvertOutput.reserve(directory: dir, baseName: "report", ext: "csv")
        XCTAssertEqual(second.lastPathComponent, "report 2.csv")
        XCTAssertEqual(third.lastPathComponent, "report 3.csv")
        XCTAssertEqual(try String(contentsOf: dir.appendingPathComponent("report.csv"), encoding: .utf8), "keep me")
    }

    func testBesideOriginalUsesInputStemAndFolder() throws {
        let dir = try tempDir()
        let input = dir.appendingPathComponent("data.json")
        try Data("{}".utf8).write(to: input)
        let url = try ConvertOutput.besideOriginal(input, ext: "csv")
        XCTAssertEqual(url.deletingLastPathComponent().standardizedFileURL, dir.standardizedFileURL)
        XCTAssertEqual(url.lastPathComponent, "data.csv")
    }

    func testDownloadsCreatesMissingDirectory() throws {
        let downloads = try tempDir().appendingPathComponent("Downloads")
        let url = try ConvertOutput.inDownloads(downloads, baseName: "converted", ext: "yaml")
        XCTAssertEqual(url.lastPathComponent, "converted.yaml")
    }
}

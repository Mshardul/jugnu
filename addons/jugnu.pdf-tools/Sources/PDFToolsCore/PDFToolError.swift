import Foundation

enum PDFToolError: Error, Equatable {
    case unreadable
    case locked
    case writeFailed
    case badPages
    case overlap
    case badOrder
    case badDegrees
    case badQuality
    case badStart
    case needsPages
    case needsTwoPDFs
    case needsOnePDF
    case needsImages
    case noForms
    case notSmaller
    case badBookmark
    case emptyTitle
}

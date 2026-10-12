import CoreGraphics
import CoreText
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers

enum PDFRaster {
    static func stampedDocument(_ page: PDFPage, label: String) -> PDFDocument? {
        let box = mediaBox(of: page)
        return documentByDrawing(box: box) { context, rect in
            page.draw(with: .mediaBox, to: context)
            draw(label, in: context, box: rect)
        }
    }

    static func redrawnDocument(_ page: PDFPage) -> PDFDocument? {
        let box = mediaBox(of: page)
        return documentByDrawing(box: box) { context, _ in
            page.draw(with: .mediaBox, to: context)
        }
    }

    static func grayscaleDocument(_ page: PDFPage) -> PDFDocument? {
        let box = mediaBox(of: page)
        let scale: CGFloat = 2
        let width = max(Int(box.width * scale), 1)
        let height = max(Int(box.height * scale), 1)
        guard let bitmap = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }
        bitmap.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: bitmap)
        guard let image = bitmap.makeImage() else {
            return nil
        }
        return documentByDrawing(box: box) { context, rect in
            context.draw(image, in: rect)
        }
    }

    static func imageDocument(_ image: CGImage) -> PDFDocument? {
        let fitted = fittedBox(pixelWidth: image.width, pixelHeight: image.height)
        return documentByDrawing(box: fitted) { context, rect in
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fill(rect)
            context.draw(image, in: rect)
        }
    }

    static func loadImage(at url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw PDFToolError.unreadable
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = (properties?[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue ?? 1
        let height = (properties?[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue ?? 1
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(width, height, 1),
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw PDFToolError.unreadable
        }
        return image
    }

    static func write(_ image: CGImage, to url: URL, format: PDFImageFormat) throws {
        let type = format == .jpeg ? UTType.jpeg.identifier : UTType.png.identifier
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type as CFString, 1, nil) else {
            throw PDFToolError.writeFailed
        }
        var properties: [CFString: Any] = [:]
        if format == .jpeg {
            properties[kCGImageDestinationLossyCompressionQuality] = 0.85
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            try? FileManager.default.removeItem(at: url)
            throw PDFToolError.writeFailed
        }
    }

    static func render(_ page: PDFPage) -> CGImage? {
        let box = mediaBox(of: page)
        let scale: CGFloat = 2
        let width = max(Int(box.width * scale), 1)
        let height = max(Int(box.height * scale), 1)
        guard let bitmap = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        bitmap.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: bitmap)
        return bitmap.makeImage()
    }

    private static func mediaBox(of page: PDFPage) -> CGRect {
        let bounds = page.bounds(for: .mediaBox)
        if bounds.width < 1 || bounds.height < 1 {
            return CGRect(x: 0, y: 0, width: 612, height: 792)
        }
        return bounds
    }

    private static func fittedBox(pixelWidth: Int, pixelHeight: Int) -> CGRect {
        var width = CGFloat(max(pixelWidth, 1))
        var height = CGFloat(max(pixelHeight, 1))
        let scale = min(1, 612 / width, 792 / height)
        width *= scale
        height *= scale
        return CGRect(x: 0, y: 0, width: width, height: height)
    }

    private static func documentByDrawing(box: CGRect, draw: (CGContext, CGRect) -> Void) -> PDFDocument? {
        let data = NSMutableData()
        var media = box
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &media, nil)
        else {
            return nil
        }
        context.beginPDFPage(nil)
        draw(context, box)
        context.endPDFPage()
        context.closePDF()
        return PDFDocument(data: data as Data)
    }

    private static func draw(_ text: String, in context: CGContext, box: CGRect) {
        let font = CTFontCreateWithName("Helvetica" as CFString, 12, nil)
        let color = CGColor(gray: 0.15, alpha: 1)
        let attributes: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: color,
        ]
        guard let attributed = CFAttributedStringCreate(nil, text as CFString, attributes as CFDictionary) else {
            return
        }
        let line = CTLineCreateWithAttributedString(attributed)
        let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        context.textPosition = CGPoint(x: box.midX - width / 2, y: box.minY + 18)
        CTLineDraw(line, context)
    }
}

enum PDFImageFormat {
    case jpeg
    case png
}

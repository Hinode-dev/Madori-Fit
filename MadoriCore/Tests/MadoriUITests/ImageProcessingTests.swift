import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import MadoriUI

final class ImageProcessingTests: XCTestCase {
    /// 単色の PNG を作る。
    private func makePNG(width: Int, height: Int) throws -> Data {
        let space = CGColorSpaceCreateDeviceRGB()
        let context = try XCTUnwrap(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try XCTUnwrap(context.makeImage())
        let output = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(
            output, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return output as Data
    }

    func testDownscalesLongEdgeToLimit() throws {
        let png = try makePNG(width: 3000, height: 2000)
        let jpeg = try XCTUnwrap(ImageProcessing.downscaledJPEG(from: png, maxPixel: 1600))
        let image = try XCTUnwrap(ImageProcessing.thumbnail(from: jpeg, maxPixel: 4000))
        XCTAssertEqual(max(image.width, image.height), 1600)
        XCTAssertEqual(Double(image.width) / Double(image.height), 1.5, accuracy: 0.01)
        XCTAssertLessThan(jpeg.count, png.count)
    }

    func testSmallImageIsNotUpscaled() throws {
        let png = try makePNG(width: 400, height: 300)
        let jpeg = try XCTUnwrap(ImageProcessing.downscaledJPEG(from: png, maxPixel: 1600))
        let image = try XCTUnwrap(ImageProcessing.thumbnail(from: jpeg, maxPixel: 4000))
        XCTAssertLessThanOrEqual(image.width, 400)
    }

    func testNonImageDataReturnsNil() {
        XCTAssertNil(ImageProcessing.downscaledJPEG(from: Data([1, 2, 3, 4])))
    }
}

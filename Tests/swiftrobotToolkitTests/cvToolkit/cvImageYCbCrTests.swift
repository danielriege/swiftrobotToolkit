import XCTest
import CoreVideo
import Accelerate
import swiftrobot
@testable import cvToolkit

@available(macOS 13.0, *)
final class cvImageYCbCrTests: XCTestCase {
    
    let width = 10
    let height = 5
    let y_v = 128
    let cbcr_v = 255
    
    func createYCbCrPixelBuffer(width_: Int = 10, height_: Int = 5) throws -> CVPixelBuffer {
        let pixelFormatType = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange // YCbCr planar format
        var pixelBuffer: CVPixelBuffer?
        let result = CVPixelBufferCreate(kCFAllocatorDefault, width_, height_, pixelFormatType, nil, &pixelBuffer)
        if result != kCVReturnSuccess {
            throw NSError()
        }
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let yBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer!, 0)
        let yBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer!, 0)
        let yHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer!, 0)
        let yWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer!, 0)
        let cbcrBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer!, 1)
        let cbcrBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer!, 1)
        let cbcrHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer!, 1)
        let cbcrWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer!, 1)
        // Fill Y plane with dummy bytes
        if let yDest = yBaseAddress {
            for y in 0..<yHeight {
                memset(yDest + (y*yBytesPerRow), Int32(y_v), yWidth) // for proper zero padding
            }
        }
        // Fill CbCr plane with dummy bytes
        if let cbcrDest = cbcrBaseAddress {
            for y in 0..<cbcrHeight {
                memset(cbcrDest + (y*cbcrBytesPerRow), Int32(cbcr_v), cbcrWidth * 2)
            }
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        return pixelBuffer!
    }
    
    func createImageMsg(randomValues: Bool = false) -> sensor_msg.Image {
        var y = Array(repeating: UInt8(y_v), count: width * height)
        if randomValues {
            y = [UInt8]()
            for _ in 0..<width*height {
                let randomValue = UInt8.random(in: 0...255)
                y.append(randomValue)
            }
        }
        let cbcr = Array(repeating: UInt8(cbcr_v), count: width * 2 * 3)
        y.append(contentsOf: cbcr)
        let msg = sensor_msg.Image(width: UInt16(width),
                                   height: UInt16(height),
                                   pixelFormat: .YCrCb420f,
                                   data: y)
        return msg
    }
    
    // MARK: Inits
    
    func testInitFromCVPixelBuffer() throws {
        let pixelBuffer = try createYCbCrPixelBuffer()
        let image = try cvImage(from: pixelBuffer)
        XCTAssertEqual(image.imageData.width, width)
        XCTAssertEqual(image.imageData.height, height)
        XCTAssertEqual(image.imageData.pixelFormat, cvPixelFormat.YCbCr)
        let imageData = image.imageData as! cvImageDataYCbCr
        let y_arr = Array(repeating: Pixel_8(y_v), count: width*height)
        XCTAssertEqual(imageData.y.array, y_arr)
        let cbcr_arr = Array(repeating: Pixel_8(cbcr_v), count: imageData.cbcr.height * imageData.cbcr.width * 2)
        XCTAssertEqual(imageData.cbcr.array, cbcr_arr)
    }
    
    /// tests that if the underlying cvPixelBuffer goes out of scope, therefore being freed from memory, the vImage points to undefined memory
    func testInitFromCVPixelBufferRetainReleaseNoOwnership() throws {
        // create cvpixelbuffer in argument so it would get released
        let image = try cvImage(from: try createYCbCrPixelBuffer(), takeOwnership: false)
        let imageData = image.imageData as! cvImageDataYCbCr
        let y_arr = Array(repeating: Pixel_8(y_v), count: width*height)
        XCTAssertNotEqual(imageData.y.array, y_arr)
    }
    
    /// tests that if the underlying cvPixelBuffer goes out of scope, therefore being freed from memory, but the vImage takes ownership,
    ///  the underlying data is not removed from memory until the vImage is deinit
    func testInitFromCVPixelBufferRetainRelease() throws {
        // create cvpixelbuffer in argument so it would get released
        var image: cvImage? = try cvImage(from: try createYCbCrPixelBuffer(), takeOwnership: true)
        let src = (image!.imageData as! cvImageDataYCbCr).y.withUnsafeBufferPointer { buffer in
            return buffer.baseAddress!
        }
        XCTAssertEqual(src.pointee as Pixel_8 , Pixel_8(y_v))
        image = nil
        XCTAssertNotEqual(src.pointee as Pixel_8 , Pixel_8(y_v))
    }
    
    func testInitImageMsg() throws {
        let image = cvImage(from: createImageMsg())
        XCTAssertEqual(image.imageData.width, width)
        XCTAssertEqual(image.imageData.height, height)
        XCTAssertEqual(image.imageData.pixelFormat, cvPixelFormat.YCbCr)
        let imageData = image.imageData as! cvImageDataYCbCr
        let y_arr = Array(repeating: Pixel_8(y_v), count: width*height)
        XCTAssertEqual(imageData.y.array, y_arr)
        let cbcr_arr = Array(repeating: Pixel_8(cbcr_v), count: imageData.cbcr.height * imageData.cbcr.width * 2)
        XCTAssertEqual(imageData.cbcr.array, cbcr_arr)
    }
    
    // MARK: Getter
    
    func testToCVPixelBuffer() throws {
        let image = cvImage(from: createImageMsg())
        let pixelBuffer = try image.toCVPixelBuffer()
        XCTAssertNotNil(pixelBuffer)
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        XCTAssertEqual(CVPixelBufferGetWidth(pixelBuffer), width)
        XCTAssertEqual(CVPixelBufferGetHeight(pixelBuffer), height)
        let src_y = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)!
        let bpr_y = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        let src_cbcr = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1)!
        let bpr_cbcr = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)
        let data_y = [UInt8](Data(bytesNoCopy: src_y, count: height * bpr_y, deallocator: .none))
        let data_cbcr = [UInt8]( Data(bytesNoCopy: src_cbcr, count: 3 * bpr_cbcr, deallocator: .none))
        
        var y_arr = Array(repeating: UInt8(0), count: bpr_y*height)
        for y in 0..<height {
            for x in 0..<width {
                y_arr[y * bpr_y + x] = UInt8(y_v)
            }
        }
        var cbcr_arr = Array(repeating: UInt8(0), count: bpr_cbcr*3)
        for y in 0..<3 {
            for x in 0..<width {
                cbcr_arr[y * bpr_cbcr + x] = UInt8(cbcr_v)
            }
        }
        XCTAssertEqual(data_y, y_arr)
        XCTAssertEqual(data_cbcr, cbcr_arr)
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    }
    
    func testPerformanceToCVPixelBuffer() throws {
        self.measureMetrics([.wallClockTime], automaticallyStartMeasuring: false) {
            let image = cvImage(from: createImageMsg(randomValues: true))
            self.startMeasuring()
            _ = try! image.toCVPixelBuffer()
            self.stopMeasuring()
        }
    }
    
    func testToPixelData() throws {
        let image = cvImage(from: createImageMsg())
        let pixelData = image.toPixelData()
        XCTAssertNotNil(pixelData)
        XCTAssertEqual(pixelData.width, width)
        XCTAssertEqual(pixelData.height, height)
        var y_arr = Array(repeating: Pixel_8(y_v), count: width*height)
        y_arr.append(contentsOf: Array(repeating: Pixel_8(cbcr_v), count: width * 2))
        XCTAssertEqual(pixelData.pixelData, y_arr)
    }
    
    func testToImageMsg() throws {
        let image = cvImage(from: createImageMsg())
        let msg = image.toImageMsg()
        XCTAssertEqual(msg.width, UInt16(width))
        XCTAssertEqual(msg.height, UInt16(height))
        var y_arr = Array(repeating: Pixel_8(y_v), count: width*height)
        y_arr.append(contentsOf: Array(repeating: Pixel_8(cbcr_v), count: width * 2))
        XCTAssertEqual(msg.pixelArray.data, y_arr)
    }
    
    // MARK: Operations
    
    func testCrop() throws {
        let image = try cvImage(from: try createYCbCrPixelBuffer())
        image.crop(CGRect(x: 1, y: 2, width: 8, height: 3))
        XCTAssertEqual(image.imageData.width, 8)
        XCTAssertEqual(image.imageData.height, 3)
        XCTAssertEqual(image.imageData.pixelFormat, cvPixelFormat.YCbCr)
        let imageData = image.imageData as! cvImageDataYCbCr
        let y_arr = Array(repeating: Pixel_8(y_v), count: 8*3)
        XCTAssertEqual(imageData.y.array, y_arr)
        let cbcr_arr = Array(repeating: Pixel_8(cbcr_v), count: 4 * 1 * 2)
        XCTAssertEqual(imageData.cbcr.array, cbcr_arr)
    }
    
    func testCropOutOfRange() throws {
        let image = try cvImage(from: try createYCbCrPixelBuffer())
        image.crop(CGRect(x: 1, y: 2, width: 20, height: 3))
        XCTAssertEqual(image.imageData.width, width)
        XCTAssertEqual(image.imageData.height, height)
        XCTAssertEqual(image.imageData.pixelFormat, cvPixelFormat.YCbCr)
        let imageData = image.imageData as! cvImageDataYCbCr
        let y_arr = Array(repeating: Pixel_8(y_v), count: width*height)
        XCTAssertEqual(imageData.y.array, y_arr)
        let cbcr_arr = Array(repeating: Pixel_8(cbcr_v), count: imageData.cbcr.height * imageData.cbcr.width * 2)
        XCTAssertEqual(imageData.cbcr.array, cbcr_arr)
    }
    
    func testPerformanceCrop() {
        self.measureMetrics([.wallClockTime], automaticallyStartMeasuring: false) {
            let image = try! cvImage(from: try! self.createYCbCrPixelBuffer(width_: 1920, height_: 1080))
            self.startMeasuring()
            image.crop(CGRect(x: 100, y: 100, width: 1000, height: 900))
            self.stopMeasuring()
        }
    }
}

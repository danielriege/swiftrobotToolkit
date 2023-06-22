import XCTest
import CoreVideo
import Accelerate
import swiftrobot
@testable import cvToolkit

@available(macOS 13.0, *)
final class cvImageGrayTests: XCTestCase {
    
    let width = 10
    let height = 5
    let gray_v = 128
    
    func createGrayPixelBuffer(width_: Int = 10, height_: Int = 5) throws -> CVPixelBuffer {
        let pixelFormatType = kCVPixelFormatType_OneComponent8
        var pixelBuffer: CVPixelBuffer?
        let result = CVPixelBufferCreate(kCFAllocatorDefault, width_, height_, pixelFormatType, nil, &pixelBuffer)
        if result != kCVReturnSuccess {
            throw NSError()
        }
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let bgrBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer!, 0)
        let bgrBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer!, 0)
        let bgrHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer!, 0)
        let bgrWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer!, 0)
        // Fill Y plane with dummy bytes
        if let bgrDest = bgrBaseAddress {
            for y in 0..<bgrHeight {
                memset(bgrDest + (y*bgrBytesPerRow), Int32(gray_v), bgrWidth)
            }
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        return pixelBuffer!
    }
    
    func createImageMsg(randomValues: Bool = false) -> sensor_msg.Image {
        var y = Array(repeating: UInt8(gray_v), count: width * height)
        if randomValues {
            y = [UInt8]()
            for _ in 0..<width*height {
                let randomValue = UInt8.random(in: 0...255)
                y.append(randomValue)
            }
        }
        let msg = sensor_msg.Image(width: UInt16(width),
                                   height: UInt16(height),
                                   pixelFormat: .Mono,
                                   data: y)
        return msg
    }
    
    // MARK: Inits
    
    func testInitFromCVPixelBuffer() throws {
        let pixelBuffer = try createGrayPixelBuffer()
        let image = try cvImage(from: pixelBuffer)
        XCTAssertEqual(image.imageData.width, width)
        XCTAssertEqual(image.imageData.height, height)
        XCTAssertEqual(image.imageData.pixelFormat, cvPixelFormat.Gray)
        let imageData = image.imageData as! cvImageDataGray
        let bgr_arr = Array(repeating: Pixel_8(gray_v), count: width*height)
        XCTAssertEqual(imageData.gray.array, bgr_arr)
    }
    
    /// tests that if the underlying cvPixelBuffer goes out of scope, therefore being freed from memory, the vImage points to undefined memory
    func testInitFromCVPixelBufferRetainReleaseNoOwnership() throws {
        // create cvpixelbuffer in argument so it would get released
        let image = try cvImage(from: try createGrayPixelBuffer(), takeOwnership: false)
        let imageData = image.imageData as! cvImageDataGray
        let bgr_arr = Array(repeating: Pixel_8(gray_v), count: width*height)
        XCTAssertNotEqual(imageData.gray.array, bgr_arr)
    }
    
    /// tests that if the underlying cvPixelBuffer goes out of scope, therefore being freed from memory, but the vImage takes ownership,
    ///  the underlying data is not removed from memory until the vImage is deinit
    func testInitFromCVPixelBufferRetainRelease() throws {
        // create cvpixelbuffer in argument so it would get released
        var image: cvImage? = try cvImage(from: try createGrayPixelBuffer(), takeOwnership: true)
        let src = (image!.imageData as! cvImageDataGray).gray.withUnsafeBufferPointer { buffer in
            return buffer.baseAddress!
        }
        XCTAssertEqual(src.pointee as Pixel_8 , Pixel_8(gray_v))
        image = nil
        XCTAssertNotEqual(src.pointee as Pixel_8 , Pixel_8(gray_v))
    }
    
    func testInitImageMsg() throws {
        let image = cvImage(from: createImageMsg())
        XCTAssertEqual(image.imageData.width, width)
        XCTAssertEqual(image.imageData.height, height)
        XCTAssertEqual(image.imageData.pixelFormat, cvPixelFormat.Gray)
        let imageData = image.imageData as! cvImageDataGray
        let y_arr = Array(repeating: Pixel_8(gray_v), count: width*height)
        XCTAssertEqual(imageData.gray.array, y_arr)
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
        let data_y = [UInt8](Data(bytesNoCopy: src_y, count: height * bpr_y, deallocator: .none))
        
        var y_arr = Array(repeating: UInt8(0), count: bpr_y*height)
        for y in 0..<height {
            for x in 0..<width {
                y_arr[y * bpr_y + x] = UInt8(gray_v)
            }
        }
        XCTAssertEqual(data_y, y_arr)
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
        let y_arr = Array(repeating: Pixel_8(gray_v), count: width*height)
        XCTAssertEqual(pixelData.pixelData, y_arr)
    }
    
    func testToImageMsg() throws {
        let image = cvImage(from: createImageMsg())
        let msg = image.toImageMsg()
        XCTAssertEqual(msg.width, UInt16(width))
        XCTAssertEqual(msg.height, UInt16(height))
        let y_arr = Array(repeating: Pixel_8(gray_v), count: width*height)
        XCTAssertEqual(msg.pixelArray.data, y_arr)
    }
    
    // MARK: Operations
    
    func testCrop() throws {
        let image = try cvImage(from: try createGrayPixelBuffer())
        image.crop(CGRect(x: 1, y: 2, width: 8, height: 3))
        XCTAssertEqual(image.imageData.width, 8)
        XCTAssertEqual(image.imageData.height, 3)
        XCTAssertEqual(image.imageData.pixelFormat, cvPixelFormat.Gray)
        let imageData = image.imageData as! cvImageDataGray
        let y_arr = Array(repeating: Pixel_8(gray_v), count: 8*3)
        XCTAssertEqual(imageData.gray.array, y_arr)
    }
    
    func testCropOutOfRange() throws {
        let image = try cvImage(from: try createGrayPixelBuffer())
        image.crop(CGRect(x: 1, y: 2, width: 20, height: 3))
        XCTAssertEqual(image.imageData.width, width)
        XCTAssertEqual(image.imageData.height, height)
        XCTAssertEqual(image.imageData.pixelFormat, cvPixelFormat.Gray)
        let imageData = image.imageData as! cvImageDataGray
        let y_arr = Array(repeating: Pixel_8(gray_v), count: width*height)
        XCTAssertEqual(imageData.gray.array, y_arr)
    }
    
    func testPerformanceCrop() {
        self.measureMetrics([.wallClockTime], automaticallyStartMeasuring: false) {
            let image = try! cvImage(from: try! self.createGrayPixelBuffer(width_: 1920, height_: 1080))
            self.startMeasuring()
            image.crop(CGRect(x: 100, y: 100, width: 1000, height: 900))
            self.stopMeasuring()
        }
    }
}

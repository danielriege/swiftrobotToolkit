//
//  cvImageDataGray.swift
//
//
//  Created by Daniel Riege on 22.06.23.
//

import Foundation
import CoreVideo
import Accelerate

@available(macOS 13.0, *)
class cvImageDataGray: cvImageData {
    var width: Int
    var height: Int
    var pixelFormat: cvPixelFormat = .Gray
    
    var gray: vImage.PixelBuffer<vImage.Planar8>
    
    var cvPixelBufferRetain: Unmanaged<CVPixelBuffer>?
    
    static var cgImageFormat = vImage_CGImageFormat(
        bitsPerComponent: 8,
        bitsPerPixel: 8,
        colorSpace: CGColorSpaceCreateDeviceGray(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
        renderingIntent: .defaultIntent)!
    static let cvImageFormat = vImageCVImageFormat.make(
        format: .formatOneComponent8,
        colorSpace: CGColorSpaceCreateDeviceGray(),
        alphaIsOpaqueHint: false)!
    
    // MARK: - Setter
    
    init(gray: vImage.PixelBuffer<vImage.Planar8>) {
        self.gray = gray
        self.width = gray.width
        self.height = gray.height
    }
    
    init(width: Int, height: Int, pixelData: UnsafeMutableRawPointer) {
        self.width = width
        self.height = height
        gray = vImage.PixelBuffer<vImage.Planar8>(data: pixelData,
                                               width: width,
                                               height: height,
                                               byteCountPerRow: nil,
                                               pixelFormat: vImage.Planar8.self)
    }
    
    ///
    /// takes ownership of the cvpixelbuffer
    init(cvPixelBuffer: CVPixelBuffer, takeOwnership: Bool) {
        CVPixelBufferLockBaseAddress(cvPixelBuffer, .readOnly)
        gray = vImage.PixelBuffer<vImage.Planar8>(referencing: cvPixelBuffer,
                                                        planeIndex: 0)
        width = gray.width
        height = gray.height
        CVPixelBufferUnlockBaseAddress(cvPixelBuffer, .readOnly)
        if takeOwnership {
            cvPixelBufferRetain = Unmanaged.passRetained(cvPixelBuffer)
        }
    }
    
    deinit {
        if let cvPixelBufferRetain = cvPixelBufferRetain {
            cvPixelBufferRetain.release()
        }
    }
    
    // MARK: - Getter
    
    func toCVPixelBuffer() throws -> CVPixelBuffer {
        var cvPixelBuffer: CVPixelBuffer?
        let result = CVPixelBufferCreate(kCFAllocatorDefault, gray.width, gray.height, kCVPixelFormatType_OneComponent8, nil, &cvPixelBuffer)
        if result != kCVReturnSuccess {
            throw cvImageError.cvPixelBufferCouldNotBeCreated
        }
        try gray.copy(to: cvPixelBuffer!,
                     cvImageFormat: cvImageDataGray.cvImageFormat,
                     cgImageFormat: cvImageDataGray.cgImageFormat)
        return cvPixelBuffer!
    }
    
    func toPixelData() -> (width: Int, height: Int, pixelData: [UInt8]) {
        let gray_arr = gray.array as [UInt8]
        return (width: gray.width, height: gray.height, pixelData: gray_arr)
    }
    
    func toCGImage() throws -> CGImage {
        if let image = gray.makeCGImage(cgImageFormat: cvImageDataGray.cgImageFormat) {
            return image
        } else {
            throw cvImageError.vImagePixelBufferToCGImageError
        }
    }
    
    func convertToPixelFormat(_ pixelFormat: cvPixelFormat) -> cvImageData {
        switch pixelFormat {
        case .YCbCr:
            return self
        case .BGRA:
            return convertToBGRA()
        case .Gray:
            return self
        }
    }
    
    private func convertToBGRA() -> cvImageDataBGRA {
        var bgra_data = [UInt8]()
        let bgra = vImage.PixelBuffer<vImage.Interleaved8x4>(data: &bgra_data,
                                                             width: width,
                                                             height: height,
                                                             byteCountPerRow: nil,
                                                             pixelFormat: vImage.Interleaved8x4.self)
        return cvImageDataBGRA(bgra: bgra)
    }
    
    // MARK: - Manipulation
    
    func crop(_ roi: CGRect) {
        if Int(roi.origin.x + roi.width) <= width &&
            Int(roi.origin.y + roi.height) <= height {
            gray = gray.cropped(to: roi)
            width = Int(roi.width)
            height = Int(roi.height)
        }
    }
    
    
}

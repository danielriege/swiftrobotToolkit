//
//  cvImageDataBGRA.swift
//
//
//  Created by Daniel Riege on 22.06.23.
//

import Foundation
import CoreVideo
import Accelerate

@available(macOS 13.0, *)
class cvImageDataBGRA: cvImageData {
    var width: Int
    var height: Int
    var pixelFormat: cvPixelFormat = .BGRA
    
    var bgra: vImage.PixelBuffer<vImage.Interleaved8x4>
    
    var cvPixelBufferRetain: Unmanaged<CVPixelBuffer>?
    
    static var cgImageFormat = vImage_CGImageFormat(
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        colorSpace: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
        renderingIntent: .defaultIntent)!
    static let cvImageFormat = vImageCVImageFormat.make(
            format: .format32BGRA,
            colorSpace: CGColorSpaceCreateDeviceRGB(),
            alphaIsOpaqueHint: false)!
    
    // MARK: - Setter
    
    init(bgra: vImage.PixelBuffer<vImage.Interleaved8x4>) {
        self.bgra = bgra
        self.width = bgra.width
        self.height = bgra.height
    }
    
    init(width: Int, height: Int, pixelData: UnsafeMutableRawPointer) {
        self.width = width
        self.height = height
        bgra = vImage.PixelBuffer<vImage.Interleaved8x4>(data: pixelData,
                                               width: width,
                                               height: height,
                                               byteCountPerRow: nil,
                                               pixelFormat: vImage.Interleaved8x4.self)
    }
    
    ///
    /// takes ownership of the cvpixelbuffer
    init(cvPixelBuffer: CVPixelBuffer, takeOwnership: Bool) {
        CVPixelBufferLockBaseAddress(cvPixelBuffer, .readOnly)
        bgra = vImage.PixelBuffer<vImage.Interleaved8x4>(referencing: cvPixelBuffer,
                                                        planeIndex: 0)
        width = bgra.width
        height = bgra.height
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
        let result = CVPixelBufferCreate(kCFAllocatorDefault, bgra.width, bgra.height, kCVPixelFormatType_32BGRA, nil, &cvPixelBuffer)
        if result != kCVReturnSuccess {
            throw cvImageError.cvPixelBufferCouldNotBeCreated
        }
        try bgra.copy(to: cvPixelBuffer!,
                     cvImageFormat: cvImageDataBGRA.cvImageFormat,
                     cgImageFormat: cvImageDataBGRA.cgImageFormat)
        return cvPixelBuffer!
    }
    
    func toPixelData() -> (width: Int, height: Int, pixelData: [UInt8]) {
        let bgra_arr = bgra.array as [UInt8]
        return (width: bgra.width, height: bgra.height, pixelData: bgra_arr)
    }
    
    func toCGImage() throws -> CGImage {
        if let image = bgra.makeCGImage(cgImageFormat: cvImageDataBGRA.cgImageFormat) {
            return image
        } else {
            throw cvImageError.vImagePixelBufferToCGImageError
        }
    }
    
    func convertToPixelFormat(_ pixelFormat: cvPixelFormat) -> cvImageData {
        return self
    }
    
    // MARK: - Manipulation
    
    func crop(_ roi: CGRect) {
        if Int(roi.origin.x + roi.width) <= width &&
            Int(roi.origin.y + roi.height) <= height {
            bgra = bgra.cropped(to: roi)
            width = Int(roi.width)
            height = Int(roi.height)
        }
    }
    
    
}

//
//  cvImageDataYCbCr.swift
//  
//
//  Created by Daniel Riege on 19.06.23.
//

import Foundation
import Accelerate
import CoreVideo
import VideoToolbox

@available(macOS 13.0, *)
class cvImageDataYCbCr: cvImageData {
    var width: Int
    var height: Int
    var pixelFormat: cvPixelFormat = .YCbCr
    
    var y: vImage.PixelBuffer<vImage.Planar8>
    var cbcr: vImage.PixelBuffer<vImage.Interleaved8x2>
    
    var cvPixelBufferRetain: Unmanaged<CVPixelBuffer>?
    
    // MARK: - Setter
    
    init(y: vImage.PixelBuffer<vImage.Planar8>, cbcr: vImage.PixelBuffer<vImage.Interleaved8x2>) {
        self.y = y
        self.cbcr = cbcr
        self.width = y.width
        self.height = y.height
    }
    
    init(width: Int, height: Int, pixelData: UnsafeMutableRawPointer) {
        self.width = width
        self.height = height
        y = vImage.PixelBuffer<vImage.Planar8>(data: pixelData,
                                               width: width,
                                               height: height,
                                               byteCountPerRow: nil,
                                               pixelFormat: vImage.Planar8.self)
        cbcr = vImage.PixelBuffer<vImage.Interleaved8x2>(data: pixelData + y.count,
                                                width: width/2,
                                                height: height/2,
                                                byteCountPerRow: nil,
                                                pixelFormat: vImage.Interleaved8x2.self)
    }
    
    ///
    /// takes ownership of the cvpixelbuffer
    init(cvPixelBuffer: CVPixelBuffer, takeOwnership: Bool) {
        CVPixelBufferLockBaseAddress(cvPixelBuffer, .readOnly)
        y = vImage.PixelBuffer<vImage.Planar8>(referencing: cvPixelBuffer,
                                               planeIndex: 0)
        cbcr = vImage.PixelBuffer<vImage.Interleaved8x2>(referencing: cvPixelBuffer,
                                                    planeIndex: 1)
        width = y.width
        height = y.height
        
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
        var pixelBuffer: CVPixelBuffer?
        let width = width
        let height = height
        let pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        let result = CVPixelBufferCreate(kCFAllocatorDefault, width, height, pixelFormat, nil, &pixelBuffer)
        guard result == kCVReturnSuccess, let outputPixelBuffer = pixelBuffer else {
            throw cvImageError.cvPixelBufferCouldNotBeCreated
        }
    
        CVPixelBufferLockBaseAddress(outputPixelBuffer, .readOnly)
        // Copy the Y plane data to the CVPixelBuffer
        let yDestination = CVPixelBufferGetBaseAddressOfPlane(outputPixelBuffer, 0)
        let yDestinationRowBytes = CVPixelBufferGetBytesPerRowOfPlane(outputPixelBuffer, 0)
        let yHeight = CVPixelBufferGetHeightOfPlane(outputPixelBuffer, 0)
        let yWidth = CVPixelBufferGetWidthOfPlane(outputPixelBuffer, 0)
        y.array.withUnsafeBufferPointer { buffer in
            for y in 0..<yHeight {
                memcpy(yDestination?.advanced(by: y * yDestinationRowBytes), buffer.baseAddress?.advanced(by: y * yWidth), yWidth)
            }
        }
        
        // Copy the CbCr plane data to the CVPixelBuffer
        let cbcrDestination = CVPixelBufferGetBaseAddressOfPlane(outputPixelBuffer, 1)
        let cbcrDestinationRowBytes = CVPixelBufferGetBytesPerRowOfPlane(outputPixelBuffer, 1)
        let cbcrHeight = CVPixelBufferGetHeightOfPlane(outputPixelBuffer, 1)
        let cbcrWidth = CVPixelBufferGetWidthOfPlane(outputPixelBuffer, 1)
        cbcr.array.withUnsafeBufferPointer { buffer in
            for y in 0..<cbcrHeight {
                memcpy(cbcrDestination?.advanced(by: y * cbcrDestinationRowBytes), buffer.baseAddress?.advanced(by: y * cbcrWidth), cbcrWidth*2)
            }
        }
        CVPixelBufferUnlockBaseAddress(outputPixelBuffer, .readOnly)
        
        return pixelBuffer!
    }
    
    func toPixelData() -> (width: Int, height: Int, pixelData: [UInt8])  {
        var y_arr = y.array as [UInt8]
        y_arr.append(contentsOf: cbcr.array as [UInt8])
        return (y.width, y.height, y_arr)
    }
    
    func toCGImage() throws -> CGImage {
        let pixelBuffer = try toCVPixelBuffer()
        var cgImage: CGImage? = nil
        if VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage) < 0 {
            throw cvImageError.cvPixelBufferToCGImageError
        }
        return cgImage!
    }
    
    // MARK: - Manipulation
    
    func convertToPixelFormat(_ pixelFormat: cvPixelFormat) -> cvImageData {
        switch pixelFormat {
        case .YCbCr:
            return self
        case .BGRA:
            return self
        case .Gray:
            return self
        }
    }
    
    func crop(_ roi: CGRect) {
        if Int(roi.origin.x + roi.width) <= width &&
            Int(roi.origin.y + roi.height) <= height {
            y = y.cropped(to: roi)
            cbcr = cbcr.cropped(to: roi)
            width = Int(roi.width)
            height = Int(roi.height)
        }
    }
    
    
}

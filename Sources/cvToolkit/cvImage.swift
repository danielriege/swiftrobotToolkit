//
//  Image.swift
//  
//
//  Created by Daniel Riege on 19.06.23.
//

import Foundation
import swiftrobot
import Accelerate

public enum cvPixelFormat {
    case YCbCr
    case BGRA
    case Gray
    
    public func asCVPixelBufferFormat() -> OSType {
        switch self {
        case .YCbCr:
            return kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        case .BGRA:
            return kCVPixelFormatType_32BGRA
        case .Gray:
            return kCVPixelFormatType_OneComponent8
        }
    }
}

public enum cvImageError: Error {
    case cvPixelBufferFormatTypeNotSupported
    case cvPixelBufferCouldNotBeCreated
    case cvPixelBufferToCGImageError
    case vImagePixelBufferToCGImageError
}

@available(macOS 13.0, *)
public class cvImage {
    internal var imageData: cvImageData
    
    public var width: Int {
        return imageData.width
    }
    public var height: Int {
        return imageData.height
    }
    public var pixelFormat: cvPixelFormat {
        return imageData.pixelFormat
    }
    
    /// only used to expand lifespan of pixel data array when using sensor_msg.Image
    private var rawPixelData: [UInt8]? = nil
    
    /// cooys values
    public init(from msg: sensor_msg.Image) {
        let width = Int(msg.width)
        let height = Int(msg.height)
        rawPixelData = msg.pixelArray.data
        
        switch msg.pixelFormat {
        case .Mono:
            imageData = cvImageDataGray(width: width,
                                        height: height,
                                        pixelData: &rawPixelData!)
        case .RGBA:
            imageData = cvImageDataBGRA(width: width,
                                        height: height,
                                        pixelData: &rawPixelData!)
        case .YCrCb420f:
            imageData = cvImageDataYCbCr(width: width,
                                         height: height,
                                         pixelData: &rawPixelData!)
        case .YCrCb420v:
            imageData = cvImageDataYCbCr(width: width,
                                             height: height,
                                             pixelData: &rawPixelData!)
        }
    }
    
    /// uses reference, no copy
    public init(from cvPixelBuffer: CVPixelBuffer, takeOwnership: Bool = true) throws {
        let pixelFormat = CVPixelBufferGetPixelFormatType(cvPixelBuffer)
        if pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange ||
            pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange {
            imageData = cvImageDataYCbCr(cvPixelBuffer: cvPixelBuffer, takeOwnership: takeOwnership)
        } else if pixelFormat == kCVPixelFormatType_32BGRA {
            imageData = cvImageDataBGRA(cvPixelBuffer: cvPixelBuffer, takeOwnership: takeOwnership)
        } else if pixelFormat == kCVPixelFormatType_OneComponent8 {
            imageData = cvImageDataGray(cvPixelBuffer: cvPixelBuffer, takeOwnership: takeOwnership)
        } else {
            throw cvImageError.cvPixelBufferFormatTypeNotSupported
        }
    }
    
    public func toCVPixelBuffer() throws -> CVPixelBuffer {
        return try imageData.toCVPixelBuffer()
    }
    
    public func toPixelData() -> (width: Int, height: Int, pixelData: [UInt8]) {
        return imageData.toPixelData()
    }
    
    public func toImageMsg() -> sensor_msg.Image {
        return sensor_msg.Image(width: UInt16(width),
                                height: UInt16(height),
                                pixelFormat: .YCrCb420f,
                                data: toPixelData().pixelData)
    }
    
    public func toCGImage() throws -> CGImage {
        return try imageData.toCGImage()
    }
    
    // MARK: - Transforms
    
    @discardableResult
    public func crop(_ roi: CGRect) -> Self {
        imageData.crop(roi)
        return self
    }
}

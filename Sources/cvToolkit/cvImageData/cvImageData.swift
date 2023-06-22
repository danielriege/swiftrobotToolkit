//
//  cvImageData.swift
//  
//
//  Created by Daniel Riege on 19.06.23.
//

import Foundation
import CoreVideo

///
///
/// is always planar under the hood
protocol cvImageData {
    var width: Int {get}
    var height: Int {get}
    var pixelFormat: cvPixelFormat {get}
    
    func toCVPixelBuffer() throws -> CVPixelBuffer
    func toPixelData() -> (width: Int, height: Int, pixelData: [UInt8])
    func toCGImage() throws -> CGImage
    
    func convertToPixelFormat(_ pixelFormat: cvPixelFormat) -> cvImageData
    func crop(_ roi: CGRect)
}

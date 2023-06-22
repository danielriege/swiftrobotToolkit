//
//  CameraViewModel.swift
//  Robocar
//
//  Created by Daniel Riege on 12.09.22.
//

import Foundation
import swiftrobot
import VideoToolbox
import cvToolkit
import CoreImage

@available(macOS 13.0, *)
public class ImageViewModel: ObservableObject {
    @Published var image: CGImage
    @Published var fps: Double = 0
    @Published var pixelFormat: String = ""
    @Published var resolution: String = ""
    
    private let context = CIContext()
    private var last_time: DispatchTime
    
    var pixelBufferCreated = false
    var lastPixelData: [UInt8] = [UInt8]()
    
    public init(channel: UInt16) {
        self.last_time = DispatchTime.now()
        self.image = ImageViewModel.createNoisyImage(width: 640, height: 480)
        NodeOrganizer.getClient().subscribe(channel: channel, priority: .utility, callback: imageCallback(msg:))
    }
    
    public func imageCallback(msg: sensor_msg.Image) {
        // This whole block should be on the main queue if camera is above 60 FPS.
        // Otherwise the lastPixelData is overwritten before the main queue has updated the UI, resulting in a EXC_BAD_ACCESS
        DispatchQueue.main.sync {
            let end_time = DispatchTime.now()   // <<<<<<<<<<   end time
            let nanoTime = end_time.uptimeNanoseconds - self.last_time.uptimeNanoseconds // <<<<< Difference in nano seconds (UInt64)
            self.fps = 1 / (Double(nanoTime) / 1_000_000_000)
            self.last_time = end_time
            self.lastPixelData = msg.pixelArray.data
            self.pixelFormat = msg.pixelFormat.rawValue
            self.resolution = String(format: "%d/%d", Int(msg.width), Int(msg.height))
            
            let cvimage = cvImage(from: msg)
            do {
                self.image = try cvimage.toCGImage()
            } catch {} // image is discared if error occurs
        }
    }
    
    private static func createNoisyImage(width: Int, height: Int) -> CGImage {
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        let context = CGContext(data: nil,
                                width: width,
                                height: height,
                                bitsPerComponent: 8,
                                bytesPerRow: width,
                                space: CGColorSpaceCreateDeviceGray(),
                                bitmapInfo: bitmapInfo.rawValue)
        
        let imageData = UnsafeMutablePointer<UInt8>(OpaquePointer(context!.data))!
        let imageBytesPerRow = context!.bytesPerRow
        
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = y * imageBytesPerRow + x
                let noise = UInt8.random(in: 0...255)
                imageData[pixelIndex] = noise
            }
        }
        
        return context!.makeImage()!
    }
}

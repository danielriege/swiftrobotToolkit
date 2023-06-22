//
//  camera.swift
//  swiftrobotmDemo
//
//  Created by Daniel Riege on 08.05.22.
//

import Foundation
import AVFoundation
import swiftrobot
import cvToolkit

public enum CameraType {
    case UltraWideAngle
    case WideAngle
    case TeleAngle
}

public enum CameraResolution {
    case w3840xh2160
    case w1920xh1080
    case w1280xh720
    case w960xh540
    case w640xh480
    case w352xh288
    
    func getWidth() -> Int {
        switch self {
        case .w3840xh2160:
            return 3840
        case .w1920xh1080:
            return 1920
        case .w1280xh720:
            return 1280
        case .w960xh540:
            return 960
        case .w640xh480:
            return 640
        case .w352xh288:
            return 352
        }
    }
    
    func getHeight() -> Int {
        switch self {
        case .w3840xh2160:
            return 2160
        case .w1920xh1080:
            return 1080
        case .w1280xh720:
            return 720
        case .w960xh540:
            return 540
        case .w640xh480:
            return 480
        case .w352xh288:
            return 288
        }
    }
}

public enum CameraFrameRate: Double {
    case fps30 = 30
    case fps60 = 60
    case fps120 = 120
    case fps240 = 240
    
    static func getUpperSupportedFrameRate(framerate: Int) -> CameraFrameRate {
        if framerate <= 30 {
            return .fps30
        } else if framerate <= 60 {
            return .fps60
        } else if framerate <= 120 {
            return .fps120
        } else {
            return .fps120
        }
    }
}

public typealias CameraPixelFormat = cvPixelFormat

#if os(iOS)
public class Camera: Node, AVCaptureVideoDataOutputSampleBufferDelegate {
    let channel: UInt16
    let queue: DispatchQueue
    let type: CameraType
    let resolution: CameraResolution
    let framerate: CameraFrameRate
    let pixelFormat: CameraPixelFormat
    let pixelFormatImageMsg: sensor_msg.Image.pixelFormat_t
    
    var captureSession: AVCaptureSession!
    var captureDevice: AVCaptureDevice?
    var videoDataOutput: AVCaptureVideoDataOutput
    var captureDeviceInput: AVCaptureDeviceInput?
    
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    public init(channel: UInt16, type: CameraType, resolution: CameraResolution, framerate: CameraFrameRate, pixelFormat: CameraPixelFormat, queue: DispatchQueue = DispatchQueue(label: "camera_node")) {
        self.channel = channel
        self.queue = queue
        self.type = type
        self.resolution = resolution
        self.framerate = framerate
        self.pixelFormat = pixelFormat
        self.pixelFormatImageMsg = self.pixelFormat.getPixelFormatImageMsg()
        self.last_time = DispatchTime.now()
        
        videoDataOutput = AVCaptureVideoDataOutput()
        captureSession = AVCaptureSession()
        
        // set device
        captureDevice = nil
        captureDeviceInput = nil
        switch self.type {
        case .UltraWideAngle:
            captureDevice = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
        case .WideAngle:
            captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        case .TeleAngle:
            captureDevice = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back)
        }
        if captureDevice == nil {
            fatalError("Camera: Could not find desired camera")
        }
        guard let captureDeviceInput = try? AVCaptureDeviceInput(device: captureDevice!) else {
            fatalError("Camera: Init failed")
        }
        self.captureDeviceInput = captureDeviceInput
        super.init()
    }
    
    deinit {
        stop()
    }
    
    public override func start() {
        super.start()
        if let captureDeviceInput = captureDeviceInput {
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.setSampleBufferDelegate(self as AVCaptureVideoDataOutputSampleBufferDelegate, queue: self.queue)
            if captureSession.canAddInput(captureDeviceInput) && captureSession.canAddOutput(videoDataOutput){
                captureSession.addInput(captureDeviceInput)
                do {
                    try configureDevice(resolution: self.resolution, framerate: self.framerate, pixelFormat: self.pixelFormat)
                } catch {
                    
                }
                
                captureSession.addOutput(videoDataOutput)
                
                DispatchQueue.global(qos: .default).async {
                    self.captureSession.startRunning()
                }
            }
        }
    }
    
    public override func stop() {
        captureSession.stopRunning()
    }
    
    func configureDevice(resolution: CameraResolution, framerate: CameraFrameRate, pixelFormat: CameraPixelFormat) throws {
        var foundConfig = false
        for vFormat in captureDevice!.formats {
            let ranges = vFormat.videoSupportedFrameRateRanges as [AVFrameRateRange]
            let dimension = CMVideoFormatDescriptionGetDimensions(vFormat.formatDescription)
            let pixelFormatAvailable = CMFormatDescriptionGetMediaSubType(vFormat.formatDescription)
            // for Grayscale we just use the luma plane of ycbcr
            var pixelFormatCV = pixelFormat.asCVPixelBufferFormat()
            if pixelFormatCV == kCVPixelFormatType_OneComponent8 {
                pixelFormatCV = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            }
            let frameRates = ranges[0]
            if frameRates.maxFrameRate == framerate.rawValue &&
                dimension.width == resolution.getWidth() &&
                dimension.height == resolution.getHeight() &&
                pixelFormatAvailable == pixelFormatCV {

                try captureDevice!.lockForConfiguration()
                captureDevice!.activeFormat = vFormat as AVCaptureDevice.Format
                captureDevice!.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(framerate.rawValue))
                captureDevice!.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(framerate.rawValue))
                captureDevice!.unlockForConfiguration()
                foundConfig = true
            }
        }
        if foundConfig == false {
            fatalError("Camera: Could not find suitable configuration")
        }
    }
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) -> Void {
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        let image = cvImage(from: imageBuffer)
        let image_msg = image.toImageMsg()
        self.client.publish(channel: self.channel, msg: image_msg)
    }
}
#endif

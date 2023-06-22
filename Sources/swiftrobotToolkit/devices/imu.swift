//
//  imu.swift
//  swiftrobotmDemo
//
//  Created by Daniel Riege on 08.05.22.
//

import Foundation
import CoreMotion
import swiftrobot

public enum IMUError: Error {
    case noDevice
}

extension IMUError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noDevice:
            return "No Motion Device available"
        }
    }
}

#if os(iOS)
public class IMU: Node {
    let channel: UInt16
    let updateInterval: TimeInterval
    let motion: CMMotionManager
    
    public init(channel: UInt16, updateInterval: TimeInterval) {
        self.channel = channel
        self.updateInterval = updateInterval
        motion = CMMotionManager()
        super.init()
    }
    
    public override func start() {
        super.start()
        if self.motion.isDeviceMotionAvailable {
            self.motion.deviceMotionUpdateInterval = self.updateInterval
            self.motion.startDeviceMotionUpdates(to: OperationQueue.main) { deviceMotion, error in
                if let deviceMotion = deviceMotion {
                    let oriX = deviceMotion.attitude.quaternion.x
                    let oriY = deviceMotion.attitude.quaternion.y
                    let oriZ = deviceMotion.attitude.quaternion.z
                    let gyroX = deviceMotion.rotationRate.x
                    let gyroY = deviceMotion.rotationRate.y
                    let gyroZ = deviceMotion.rotationRate.z
                    let accX = deviceMotion.userAcceleration.x + deviceMotion.gravity.x
                    let accY = deviceMotion.userAcceleration.y + deviceMotion.gravity.y
                    let accZ = deviceMotion.userAcceleration.z + deviceMotion.gravity.z
                    
                    let imu_msg = sensor_msg.IMU(orientationX: Float(oriX),
                                                  orientationY: Float(oriY),
                                                  orientationZ: Float(oriZ),
                                                  angularVelocityX: Float(gyroX),
                                                  angularVelocityY: Float(gyroY),
                                                  angularVelocityZ: Float(gyroZ),
                                                  linearAccelerationX: Float(accX),
                                                  linearAccelerationY: Float(accY),
                                                  linearAccelerationZ: Float(accZ))
                    self.client.publish(channel: self.channel, msg: imu_msg)
                }
            }
            self.started()
            self.failed(error: IMUError.noDevice)
        } else {
            self.failed(error: IMUError.noDevice)
        }
    }
}
#endif

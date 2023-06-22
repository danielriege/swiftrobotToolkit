//
//  Node.swift
//  Robocar
//
//  Created by Daniel Riege on 19.09.22.
//

import Foundation
import swiftrobot

enum NodeState {
    case idle
    case starting
    case running
    case stoped
    case failed
}

open class Node: NSObject {
    
    public let id: Int
    internal var state: NodeState
    public var client: SwiftRobotClient
    
    public override init() {
        self.id = Node.getUniqueID()
        self.state = .idle
        self.client = NodeOrganizer.getClient()
    }
    
    open func start() {
        self.state = .starting
    }
    
    open func stop() {
        self.state = .stoped
    }
    
    public func started(filename: String = #file, function: String = #function) {
        self.state = .running
        print("running")
    }
    
    public func failed(error: Error, filename: String = #file, function: String = #function) {
        self.state = .failed
        print(error.localizedDescription)
    }
    
    static func == (lhs: Node, rhs: Node) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: unique id

extension Node {
    static var nextID = 0
    static func getUniqueID() -> Int {
        nextID += 1
        return nextID
    }
}

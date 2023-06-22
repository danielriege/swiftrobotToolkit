//
//  NodeOrganizer.swift
//  Robocar
//
//  Created by Daniel Riege on 16.11.22.
//

import Foundation
import swiftrobot

enum NodeOrganizerState {
    case idle
    case running
}

public class NodeOrganizer {
    private static let organizer_ = NodeOrganizer()
    private static var client_ = SwiftRobotClient()
    
    public static func get() -> NodeOrganizer {
        return NodeOrganizer.organizer_
    }
    public static func getClient() -> SwiftRobotClient {
        return client_
    }
    
    private var client: SwiftRobotClient {
        return NodeOrganizer.client_
    }
    private var nodes: [Node]
    private var state: NodeOrganizerState
    
    private init() {
        self.state = .idle
        self.nodes = [Node]()
    }
    
    public func useCustom(client: SwiftRobotClient) {
        NodeOrganizer.client_ = client
    }
    
    public func add(node: Node) {
        self.nodes.append(node)
        if state == .running {
            node.start()
        }
    }
    
    public func remove(node: Node) {
        node.stop()
        self.nodes.removeAll(where: {$0 == node})
    }
    
    public func start() {
        if state == .idle {
            self.client.subscribe(channel: 0) { (msg: internal_msgs.UpdateMsg) in
                print("Device \(msg.clientID) is now \(msg.status)")
            }
            self.client.start()
            for node in nodes {
                node.start()
            }
            self.state = .running
        }
    }
    
    public func stop() {
        if state == .running {
            for node in nodes {
                node.stop()
            }
            self.state = .idle
        }
    }
}

//
//  ViewController.swift
//  phantom
//
//  Created by Rake Yang on 2020/3/29.
//  Copyright © 2020 BinaryParadise. All rights reserved.
//

import UIKit
import Starscream

class ViewController: UIViewController {
    var socket:WebSocket?
    var isConnected = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        var request = URLRequest(url: URL(string: "ws://127.0.0.1:9000/channel/neverland")!)
        request.timeoutInterval = 5 // Sets the timeout for the connection
        request.setValue("phantom-core", forHTTPHeaderField: "Sec-WebSocket-Protocol")
        socket = WebSocket(request: request)
        socket?.delegate = self
        socket?.onEvent = { event in
            switch event {
            case .connected(let headers):
                self.isConnected = true
                print("websocket is connected: \(headers)")
            case .disconnected(let reason, let code):
                self.isConnected = false
                print("websocket is disconnected: \(reason) with code: \(code)")
            case .text(let string):
                print("Received text: \(string)")
            case .binary(let data):
                print("Received data: \(data.count)")
            case .ping(_):
                break
            case .pong(_):
                break
            case .viablityChanged(_):
                break
            case .reconnectSuggested(_):
                break
            case .cancelled:
                self.isConnected = false
            case .error(let error):
                self.isConnected = false
                print("\(error?.localizedDescription)")
            }
        }
        socket?.connect()
    }
}

extension ViewController : WebSocketDelegate {
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        
    }
}

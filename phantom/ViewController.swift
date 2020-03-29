//
//  ViewController.swift
//  phantom
//
//  Created by Rake Yang on 2020/3/29.
//  Copyright © 2020 BinaryParadise. All rights reserved.
//

import UIKit
import CocoaAsyncSocket

class ViewController: UIViewController {
    var asyncSock:GCDAsyncSocket?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        asyncSock = GCDAsyncSocket.init(delegate: self, delegateQueue: DispatchQueue.global())
        do {
            try asyncSock?.connect(toHost: "phantom.run.goorm.io", onPort: 443, withTimeout: 15)
            asyncSock?.startTLS([ : ])
        } catch {
            print("\(#function)+\(#line) \(error.localizedDescription)")
        }
    }

}

extension ViewController: GCDAsyncSocketDelegate {
    func socketDidSecure(_ sock: GCDAsyncSocket) {
    }
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        print("\(#function)\(err?.localizedDescription)")
    }
    
    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        print("\(#function)+\(#line) \(host):\(port)")
        sock.readData(withTimeout: 10, tag: 0x1000)
//        sock.write("GET / HTTP/1.1".data(using: String.Encoding.utf8), withTimeout: 15, tag: 10100)
    }
    
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        print(String.init(data: data, encoding: String.Encoding.utf8))
    }
}

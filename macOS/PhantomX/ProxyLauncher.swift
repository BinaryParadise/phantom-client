//
//  ProxyLauncher.swift
//  PhantomX
//
//  Created by Rake Yang on 2020/4/4.
//  Copyright © 2020 BinaryParadise. All rights reserved.
//

import Cocoa
import CocoaAsyncSocket

let AppResourcesPath = Bundle.main.bundlePath + "/Contents/Resources"
var HttpServerPacPort = UserDefaults.getString(forKey: .localPacPort) ?? "11085"
var PACUrl = "http://192.168.50.64:" + String(HttpServerPacPort) + "/pac/proxy.js"

var webServer = GCDAsyncSocket()

enum RunMode: String {
    case global
    case off
    case manual
    case pac
    case backup
    case restore
}
class ProxyLauncher: NSObject {
    static let shared = ProxyLauncher()
    var asyncSock:GCDAsyncSocket?
    var clientSock:GCDAsyncSocket?

    private override init() {
        super.init()
        asyncSock = GCDAsyncSocket.init(delegate: self, delegateQueue: DispatchQueue.global())
    }
    static func setSystemProxy(mode: RunMode, httpPort: String = "", sockPort: String = "") {
        let task = Process.launchedProcess(launchPath: AppResourcesPath+"/PhantomXTool", arguments: ["-mode", mode.rawValue, "-pac-url", PACUrl, "-http-port", httpPort, "-sock-port", sockPort])
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            NSLog("setSystemProxy " + mode.rawValue + " succeeded.")
        } else {
            NSLog("setSystemProxy " + mode.rawValue + " failed.")
        }
    }
    
    static func startHttpServer() {
        do {
            try shared.asyncSock?.accept(onPort: UInt16(HttpServerPacPort)!)
            print("webServer.start at:\(HttpServerPacPort)\n")
            ProxyLauncher.setSystemProxy(mode: .pac, httpPort: "2080", sockPort: "")
        } catch {
            print("\(#function)+\(#line) webServer\(HttpServerPacPort).start error:\(error.localizedDescription)")
        }
    }
}

extension ProxyLauncher: GCDAsyncSocketDelegate {
    func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        clientSock = newSocket
        newSocket.readData(withTimeout: 5, tag: 100)
    }
    
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        if tag == 100 {
            let headers = String.init(data: data, encoding: .utf8)?.components(separatedBy: "\r\n")
            if (headers?.first?.contains("/pac/proxy.js"))! {
                do {
                    let pacJS = try Data.init(contentsOf: URL.init(fileURLWithPath: AppResourcesPath+"/pac/proxy.js"))
                    let res = """
                    HTTP/1.1 200 OK
                    Content-Length: \(pacJS.count)
                    Server: PhantomX 1.0
                    Content-Type: application/javascript\r\n\r\n
                    """
                    sock.write(res.data(using: .utf8), withTimeout: 3, tag: 200)
                    sock.write(pacJS, withTimeout: 3, tag: 201)
                    sock.disconnectAfterWriting()
                } catch {
                    print("\(error)")
                }
            }
            
        }
    }
}

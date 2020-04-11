//
//  ProxyNegotiation.swift
//  PhantomX
//
//  Created by Rake Yang on 2020/4/5.
//  Copyright © 2020 BinaryParadise. All rights reserved.
//

import Foundation
import CocoaAsyncSocket
import Starscream
import CocoaLumberjack

//let WEBSOCKET_ADDR  = "wss://52.79.227.149:52771/phantom"
let WEBSOCKET_ADDR  = "wss://phantom.neverland.life/huanying";

#if DEBUG
let TIME_OUT    = 180.0
#else
let TIME_OUT    = 60.0
#endif

enum SOCKS5_KEY:Int {
    /// 未指定
    case unspecified = 0
    /// 协商
    case negotiation = 200
    /// 协商回复
    case negotiation_res = 201
    /// 连接请求
    case connect = 202
    /// 连接回复
    case connect_res = 203
    /// 数据转发
    case data_forward = 204
    /// 数据转发响应
    case data_forward_res = 205
    /// 确认是否还有转发请求
    case data_forward_try = 206
    /// HTTP代理已连接
    case http_connected = 207
}

var semaphore = DispatchSemaphore.init(value: 6)
var proxies:[ProxyNegotiation] = []
var idleProxy:[ProxyNegotiation] = []

/// 代理协商对象
class ProxyNegotiation: NSObject {
    var sock:GCDAsyncSocket?
    var proxyData: Data
    var webSocket:WebSocket?
    var connected = false
    var idx = 0
    var httpProxy = false
    public var onEvent: ((WebSocketEvent) -> Void)?

    init(sock: GCDAsyncSocket?) {
        proxyData = Data.init()
        super.init()
        self.sock = sock
    }
    
    func createProxy() -> Void {
        var request = URLRequest(url: URL(string: WEBSOCKET_ADDR)!)
        request.timeoutInterval = 15 // Sets the timeout for the connection
        request.setValue("phantom-core", forHTTPHeaderField: "Sec-WebSocket-Protocol")
        let pinner = FoundationSecurity(allowSelfSigned: true)
        webSocket = WebSocket(request: request, certPinner: pinner)
        webSocket?.onEvent = { event in
            switch event {
            case .connected(let headers):
                self.connected = true
                idleProxy.append(self)
                DDLogDebug("[\(self.idx)]已连接...\(idleProxy.count)/\(proxies.count)")
                semaphore.signal()
            case .binary(let data):
                self.didReceiveBinary(data: data)
            case .ping(_):
                break
            case .pong(_):
                break
            case .viablityChanged(_):
                break
            case .reconnectSuggested(_):
                break
            case .cancelled:
                self.connected = false
                DDLogVerbose("")
            case .error(let error):
                self.connected = false
                DDLogError("\(WEBSOCKET_ADDR) \(error)")
            default :
                break
            }
        }
        DDLogDebug("开始连接")
        self.webSocket?.connect()        
    }
    
    func didReceiveBinary(data: Data) -> Void {
        DDLogWarn("[\(data.count)]\(String.init(data: data, encoding: .utf8))")
        if data.count > 0 {
            if httpProxy {
                sock?.writeData(data: data, forKey: .http_connected)
            } else {
                sock?.writeData(data: data, forKey: .data_forward_res)
            }
        }
    }
    
    func forward(data: Data) -> Void {
        if self.connected {
            var encryptData = Data()
            encryptData.append(0x01)
            encryptData.append(proxyData)
            encryptData.append(data)
            webSocket?.write(data: encryptData, completion: {
                DDLogDebug("Data forward to server.")
            })
        }
    }
    
    func httpConnect(data: Data) -> Void {
        httpProxy = true
        if self.connected {
            var encryptData = Data()
            encryptData.append(0x01)
            encryptData.append(proxyData)
            encryptData.append(data)
            webSocket?.write(data: encryptData, completion: {
                DDLogDebug("Data forward to server.")
            })
        }
    }
}

extension ProxyNegotiation {
    /// 创建10个连接对象备用
    static func creatWSocks() -> Void {
        for i in 0...5 {
            let proxy = ProxyNegotiation.init(sock: nil)
            proxy.idx = i
            proxy.createProxy()
            proxies.append(proxy)
            DispatchQueue.global().async {
                semaphore.wait()
            }
        }
    }
}

// 自定义证书校验
extension ProxyNegotiation: CertificatePinning {
    func evaluateTrust(trust: SecTrust, domain: String?, completion: ((PinningState) -> ())) {
        completion(.success)
    }
}

extension GCDAsyncSocket {
    func readData(forKey key: SOCKS5_KEY) -> Void {
        readData(withTimeout: TIME_OUT, tag: key.rawValue)
    }
    
    func writeData(data: Data?, forKey key: SOCKS5_KEY) -> Void {
        write(data, withTimeout: TIME_OUT, tag: key.rawValue)
    }
}

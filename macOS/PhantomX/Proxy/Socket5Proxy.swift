//
//  Socket5Proxy.swift
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
let WEBSOCKET_ADDR  = "wss://localhost:8443/phantom";

#if DEBUG
let TIME_OUT    = 60.0
#else
let TIME_OUT    = 30.0
#endif

enum SOCKS5_KEY:Int {
    /// 未指定
    case unspecified = 1
    /// 协商
    case negotiation = 200
    /// 协商回复
    case negotiation_res = 201
    /// 连接请求
    case connect = 300
    /// 连接回复
    case connect_res = 301
    /// 数据转发
    case data_forward = 400
    /// 数据转发响应
    case data_forward_res = 401
    /// 确认是否还有转发请求
    case data_forward_try = 500
    /// HTTP代理已连接
    case http_connected = 207
}

enum WSPingStatus: UInt8 {
    case ping = 0x00
    case targetConnected = 0x01
    case targetClosed    = 0x02
}

/// 代理协商对象
class Socket5Proxy: NSObject {
    var sock:GCDAsyncSocket?
    var proxyData: Data
    var webSocket:WebSocket?
    var targetAddress:String?
    var targetPort:Int = 0
    public var onEvent: ((WebSocketEvent) -> Void)?

    init(sock: GCDAsyncSocket?) {
        proxyData = Data.init()
        self.sock = sock
    }
    
    func startConnect(address:String?, port:Int, completion:@escaping ((Bool) -> Void)) -> Void {
        targetAddress = address
        targetPort = port
        var request = URLRequest(url: URL(string: WEBSOCKET_ADDR)!)
        request.timeoutInterval = 15 // Sets the timeout for the connection
        request.setValue("phantom-core", forHTTPHeaderField: "Sec-WebSocket-Protocol")
        let pinner = FoundationSecurity(allowSelfSigned: true)
        webSocket = WebSocket(request: request, certPinner: pinner)
        webSocket?.onEvent = { event in
            switch event {
            case .connected(let headers):
                DDLogDebug("成功连接到\(WEBSOCKET_ADDR)")
                self.connectTarget()
            case .binary(let data):
                self.didReceiveBinary(data: data)
            case .ping(let data):
                self.didReceivePing(data: data ?? Data.init(), completion: completion)
            case .pong(_):
                break
            case .viablityChanged(_):
                break
            case .reconnectSuggested(_):
                break
            case .cancelled:
                completion(false)
                DDLogVerbose("")
            case .error(let error):
                completion(false)
                DDLogError("\(WEBSOCKET_ADDR) \(error)")
            default :
                break
            }
        }
        DDLogDebug("开始连接到\(WEBSOCKET_ADDR)")
        self.webSocket?.connect()
    }
    
    func didReceiveBinary(data: Data) -> Void {
        DDLogWarn("收到回传数据...\(data.count)")
        sock?.writeData(data: data, forKey: .data_forward_res)
    }
    
    func didReceivePing(data: Data, completion:((Bool) -> Void)) -> Void {
        let pingStats = WSPingStatus(rawValue: data.first ?? 0x00)
        switch pingStats {
        case .targetConnected:
            completion(data[1] == 0x00)
        case .targetClosed:
            self.clear()
        default:
            break
        }
    }
    
    func connectTarget() {
        DDLogWarn("连接目标服务\(targetAddress):\(targetPort)")
        var encryptData = Data()
        encryptData.append(0x01)
        encryptData.append(targetAddress?.count.toUInt8().last ?? 0x00)
        encryptData.append(contentsOf: targetAddress!.bytes)
        encryptData.append(contentsOf: targetPort.toUInt16())
        webSocket?.write(data: encryptData, completion: {
        })
    }
    
    func forward(data: Data) -> Void {
        var encryptData = Data()
        encryptData.append(0x02)
        encryptData.append(data)
        webSocket?.write(data: encryptData, completion: {
            DDLogDebug("Data forward to server.")
        })
    }
    
    func clear() -> Void {
        sock?.disconnect()
        webSocket?.disconnect()
    }
}

// 自定义证书校验
extension Socket5Proxy: CertificatePinning {
    func evaluateTrust(trust: SecTrust, domain: String?, completion: ((PinningState) -> ())) {
        completion(.success)
    }
}

extension GCDAsyncSocket {
    func readData(forKey key: SOCKS5_KEY) -> Void {
        readData(forKey: key, withTimeout: TIME_OUT)
    }
    
    func readData(forKey key: SOCKS5_KEY, withTimeout: TimeInterval) -> Void {
        readData(withTimeout: withTimeout, tag: key.rawValue)
    }
    
    func writeData(data: Data?, forKey key: SOCKS5_KEY) -> Void {
        write(data, withTimeout: TIME_OUT, tag: key.rawValue)
    }
}

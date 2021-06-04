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

//let WEBSOCKET_ADDR  = "wss://csgo.zhegebula.top/phantom";
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

enum CommandType: UInt8 {
    case authorization  =   0x01
    case connect        =   0x02
    case forward        =   0x03
    case transport      =   0x04
    case unsupport      =   0x00
}

/// 代理协商对象
class Socket5Proxy: NSObject {
    var sock:GCDAsyncSocket
    var proxyData: Data
    var webSocket:WebSocket?
    var targetAddress: Destination?
    var targetPort:Int = 0
    public var onEvent: ((WebSocketEvent) -> Void)?

    init(sock: GCDAsyncSocket) {
        proxyData = Data.init()
        self.sock = sock
    }
    
    func startConnect(_ address: Destination, completion:@escaping ((Bool) -> Void)) -> Void {
        targetAddress = address
        var request = URLRequest(url: URL(string: WEBSOCKET_ADDR)!)
        request.timeoutInterval = 15 // Sets the timeout for the connection
        request.setValue("phantom-core", forHTTPHeaderField: "Sec-WebSocket-Protocol")
        let pinner = FoundationSecurity(allowSelfSigned: true)
        webSocket = WebSocket(request: request, certPinner: pinner)
        webSocket?.onEvent = { event in
            switch event {
            case .connected(let headers):
                DDLogDebug("成功连接到\(WEBSOCKET_ADDR) \(headers)")
                self.authorization(id: "3b8e10b8-8c7b-11eb-8dcd-0242ac130003")
            case .binary(let data):
                self.didReceiveBinary(data: data, completion: completion)
            case .ping(let data):
                self.didReceivePing(data: data ?? Data.init(), completion: completion)
            case .pong(_):
                break
            case .viabilityChanged(_):
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
    
    func didReceiveBinary(data: Data, completion: ((Bool) -> Void)?) -> Void {
        if let type = CommandType.init(rawValue: data.first ?? 0x00) {
            DDLogWarn("收到回传数据...\(data.count)")
            let resData = data.subdata(in: 1 ..< data.count-1)
            switch type {
            case .authorization:
                connectTarget()
            case .connect:
                completion?(true)
            case .forward:
                sock.writeData(data: resData, forKey: .data_forward_res)
            case .transport:
                sock.writeData(data: resData, forKey: .data_forward_res)
            default:
                DDLogError("数据格式错误")
            }
        }
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
    
    func authorization(id: String) {
        DDLogInfo("开始授权")
        var secData = Data()
        secData.append(CommandType.authorization.rawValue)
        secData.append(UInt8(id.count))
        secData.append(contentsOf: id.bytes)
        webSocket?.write(data: secData, completion: {
            
        })
    }
    
    func connectTarget() {
        guard let dst = targetAddress else { return }
        DDLogWarn("连接目标服务\(dst.description)")
        var encryptData = Data()
        encryptData.append(CommandType.connect.rawValue)
        encryptData.append(dst.addr.count.toUInt8().last ?? 0x00)
        encryptData.append(dst.addr)
        encryptData.append(contentsOf: dst.port.toUInt16())
        webSocket?.write(data: encryptData, completion: {
        })
    }
    
    func forward(data: Data) -> Void {
        var encryptData = Data()
        encryptData.append(CommandType.forward.rawValue)
        encryptData.append(data)
        webSocket?.write(data: encryptData, completion: {
            DDLogDebug("Data forward to server.")
        })
    }
    
    func clear() -> Void {
        sock.disconnect()
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

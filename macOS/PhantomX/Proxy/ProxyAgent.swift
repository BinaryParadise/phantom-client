//
//  ProxyAgent.swift
//  PhantomX
//
//  Created by Rake Yang on 2020/4/17.
//  Copyright © 2020 BinaryParadise. All rights reserved.
//

import Foundation
import CocoaAsyncSocket
import CocoaLumberjack
import Canary

let HTTPPort = 12080

class ProxyAgent: NSObject {
    var asyncSock:GCDAsyncSocket?
    var isRunning = false
    var clients:[Int:Socket5Proxy] = [:]
    
    func startProxy() -> Void {
        self.asyncSock = GCDAsyncSocket.init(delegate: self, delegateQueue: DispatchQueue.global())
        do {
            try asyncSock?.accept(onPort: UInt16(HTTPPort))
            DDLogDebug("监听成功:127.0.0.1:\(HTTPPort)\n")
        } catch {
            DDLogError("\(#function)+\(#line) \(error.localizedDescription)")
        }
    }
    
    func stopProxy() -> Void {
        asyncSock?.disconnectAfterReadingAndWriting()
        clients.forEach { (hash, client) in
            client.webSocket?.disconnect(closeCode: 1000)
            client.sock?.disconnectAfterReadingAndWriting()
        }
    }
}

/// 客户端代理协商
extension ProxyAgent: GCDAsyncSocketDelegate {
    func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        clients[newSocket.hash] = Socket5Proxy.init(sock: newSocket)
        newSocket.readData(forKey: .unspecified)
    }
    
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        DDLogInfo("【\(tag)】...\(data.count)")
        let readTag = SOCKS5_KEY(rawValue: tag)
        switch readTag {
        case .unspecified:
            handshake(sock, data: data)
        case .connect:
            clientConnect(sock, data: data)
        case .data_forward_try:
            dataForward(sock, data: data)
        default:
            dataForward(sock, data: data)
            break
        }
    }
    
    func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        DDLogDebug("【\(tag)】")
        let writeTag = SOCKS5_KEY(rawValue: tag)
        switch writeTag {
        case .negotiation_res:
            sock.readData(forKey: .connect)
        case .connect_res:
            sock.readData(forKey: .data_forward)
        case .data_forward_res:
            sock.readData(forKey: .data_forward_try, withTimeout: 3)
        case .http_connected:
            sock.readData(forKey: .data_forward_try, withTimeout: 3)
        default:
            break
        }
    }
    
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        DDLogWarn("\(err)")
        let proxy = clients.removeValue(forKey: sock.hash)
        proxy?.clear()
    }
    
    func handshake(_ sock: GCDAsyncSocket, data: Data) -> Void {
        var method = "NO ACCEPTABLE METHODS"
        switch data[1] {
            case 0x00:method = "NO AUTHENTICATION REQUIRED"
            case 0x01:method = "GSSAPI"
            case 0x02:method = "USERNAME/PASSWORD"
            case 0x03...0x7F:method = "IANA ASSIGNED"
            case 0x80...0xFE:method = "RESERVED FOR PRIVATE METHODS"
            case 0xFF:fallthrough
            default: break
        }

        DDLogVerbose("SOCK5 Proxy Handshake > \(method)")
        var resData = Data.init()
        resData.append(0x05)
        resData.append(0x00)
        sock.writeData(data: resData, forKey: .negotiation_res)
    }
    
    func clientConnect(_ sock: GCDAsyncSocket, data: Data) -> Void {
        //CONNECT X’01’
        //BIND X’02’
        //UDP ASSOCIATE X’03’
        let cmd = data[1]
        assert(cmd == 0x01)
        //RSV保留字，值长度为1个字节
        // IP V4 address: X’01’
        // DOMAINNAME: X’03’
        // IP V6 address: X’04’
        let atyp = data[3]
        assert(atyp == 0x03)
        //DST.ADDR代表远程服务器的地址，根据ATYP进行解析，值长度不定。
        let proxy = clients[sock.hash]
        clients[sock.hash] = proxy
        var hostAddr:String?
        // DST.PORT代表远程服务器的端口，要访问哪个端口的意思，值长度2个字节
        let portData = data.subdata(in: Data.Index(data.count-2)..<data.count)
        if atyp == 0x03 {//路由规则
            hostAddr = String.init(data: data.subdata(in: 5..<data.count-2), encoding: .utf8)
        } else if atyp == 0x04 {
            hostAddr = String.init(data: data.subdata(in: 5..<11), encoding: .utf8)
        } else {
            hostAddr = String.init(data: data.subdata(in: 5..<9), encoding: .utf8)
        }
        proxy?.startConnect(address: hostAddr, port: Int(portData.toUInt16()), completion: { (connected) in
            var resData = Data.init()
            resData.append(0x05)
            //状态
            //0x00 = succeeded
            //0x01 = general SOCKS server failure
            //0x02 = connection not allowed by ruleset
            //0x03 = Network unreachable
            //0x04 = Host unreachable
            //0x05 = Connection refused
            //0x06 = TTL expired
            //0x07 = Command not supported
            //0x08 = Address type not supported
            //0x09 = to 0xFF unassigned
            resData.append(connected ? 0x00:0x01)
            resData.append(0x00)
            resData.append(atyp)
            resData.append(0x04)
            resData.append(0x7F)
            resData.append(0x00)
            resData.append(0x00)
            resData.append(contentsOf: HTTPPort.toUInt16())
            resData.append(0x30)
            sock.writeData(data: resData, forKey: .connect_res)
        })
    }
    
    func dataForward(_ sock: GCDAsyncSocket, data: Data) -> Void {
        let proxy = clients[sock.hash]
        if (proxy != nil) {
            proxy?.forward(data: data)
        }
    }
}

//
//  ViewController.swift
//  PhantomX
//
//  Created by Rake Yang on 2020/4/4.
//  Copyright © 2020 BinaryParadise. All rights reserved.
//

import Cocoa
import CocoaAsyncSocket
import CocoaLumberjack

let HTTPPort = 12080

class ViewController: NSViewController {
    var asyncSock:GCDAsyncSocket?
    var isRunning = false
    var clients:[Int:ProxyNegotiation] = [:]
    let sema = DispatchSemaphore.init(value: 10)

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        ProxyNegotiation.creatWSocks()
        asyncSock = GCDAsyncSocket.init(delegate: self, delegateQueue: DispatchQueue.global())
        startProxy(AnyClass.self)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    @IBAction func startProxy(_ sender: Any) -> Void {
        isRunning = true
        if isRunning {
            do {
                try asyncSock?.accept(onPort: UInt16(HTTPPort))
                DDLogDebug("监听成功:127.0.0.1:\(HTTPPort)\n")
            } catch {
                DDLogError("\(#function)+\(#line) \(error.localizedDescription)")
            }
        }
    }
}

/// 客户端代理协商
extension ViewController: GCDAsyncSocketDelegate {
    func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        DDLogDebug("【\(newSocket.hash)】")
        sema.wait();
        let proxy = idleProxy.removeLast()
        proxy.sock = newSocket
        clients[newSocket.hash] = proxy
        newSocket.readData(forKey: .unspecified)
    }
    
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        DDLogInfo("【\(sock.hash)-\(tag)】> \(data.count)")
        let readTag = SOCKS5_KEY(rawValue: tag)
        switch readTag {
        case .unspecified:
            handshake(sock, data: data)
        case .connect:
            clientConnect(sock, data: data)
        case .data_forward_try:
            if data.count > 0 {
                dataForward(sock, data: data)
            } else {
                sema.signal()
            }
        default:
            dataForward(sock, data: data)
            break
        }
    }
    
    func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        DDLogDebug("【\(sock.hash)-\(tag)】")
        let writeTag = SOCKS5_KEY(rawValue: tag)
        switch writeTag {
        case .negotiation_res:
            sock.readData(forKey: .connect)
        case .connect_res:
            sock.readData(forKey: .data_forward)
        case .data_forward_res:
            sock.readData(forKey: .data_forward_try)
        default:
            break
        }
    }
    
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        DDLogWarn("【\(sock.hash)】\(err)")
        clients.removeValue(forKey: sock.hash)
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
        let proxyNe = clients[sock.hash]
        //原样转发，不作处理
        proxyNe?.proxyData = data
        if atyp == 0x03 {
//            proxyNe?.bindAddr = String.init(data: data.subdata(in: 5..<data.count-2), encoding: .utf8)
            //DST.PORT代表远程服务器的端口，要访问哪个端口的意思，值长度2个字节
//            let subData = NSData.init(data: data.subdata(in: Data.Index(data.count-2)..<data.count))
        }
        
        var resData = Data.init()
        resData.append(0x05)
        resData.append(0x00)
        resData.append(0x00)
        resData.append(atyp)
        resData.append(0x04)
        resData.append(0x7F)
        resData.append(0x00)
        resData.append(0x00)
        resData.append(0x01)
        resData.append(0x2F)
        resData.append(0x30)
        sock.writeData(data: resData, forKey: .connect_res)
    }
    
    func dataForward(_ sock: GCDAsyncSocket, data: Data) -> Void {
        let proxyNe = clients[sock.hash]
        if (proxyNe != nil) {
            proxyNe?.forward(data: data)
        }
    }
}

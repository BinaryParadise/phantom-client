//
//  ViewController.swift
//  PhantomX
//
//  Created by Rake Yang on 2020/4/4.
//  Copyright © 2020 BinaryParadise. All rights reserved.
//

import Cocoa
import Starscream
import CocoaAsyncSocket

let HTTPPort = 12080

class ViewController: NSViewController {
    var socket:WebSocket?
    var isConnected = false
    var asyncSock:GCDAsyncSocket?
    var isRunning = false
    var clients:[GCDAsyncSocket] = []

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
                print("监听成功:0.0.0.0:\(HTTPPort)\n")
            } catch {
                print("\(#function)+\(#line) \(error.localizedDescription)")
            }
        }
    }
}

extension ViewController : WebSocketDelegate {
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        
    }
}

extension ViewController: GCDAsyncSocketDelegate {
    func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        clients.append(newSocket);
        newSocket.readData(withTimeout: 15, tag: 10)
    }
    
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        print("\(#function) \(data.count)")
        if data[0] == 0x05 {
            handshake(data: data, sock)
        } else {
            //转发数据
        }
    }
    
    func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        if tag == 0 {
            sock.disconnect()
        }
    }
    
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        clients.removeAll { (item) -> Bool in
            return item == sock
        }
    }

    func handshake(data:Data, _ sock: GCDAsyncSocket) -> Void {
        if data.count == 3 {//SOCKS5 Proxy
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

            print("SOCK5 Proxy Handshake \(method)")
            var resData = Data.init()
            resData.append(0x05)
            resData.append(0x00)
            sock.write(resData, withTimeout: 3, tag: 0x502)
            sock.readData(withTimeout: 3, tag: 0x502)
        } else {
            //CONNECT X’01’
            //BIND X’02’
            //UDP ASSOCIATE X’03’
            let cmd = data[1]
            //RSV保留字，值长度为1个字节
            // IP V4 address: X’01’
            // DOMAINNAME: X’03’
            // IP V6 address: X’04’
            let atyp = data[3]
            //DST.ADDR代表远程服务器的地址，根据ATYP进行解析，值长度不定。
            let domain = String.init(data: data.subdata(in: 5..<data.count-2), encoding: .utf8)
            //DST.PORT代表远程服务器的端口，要访问哪个端口的意思，值长度2个字节
            let subData = NSData.init(data: data.subdata(in: Data.Index(data.count-2)..<data.count))
            var port:UInt16 = 0
            subData.getBytes(&port, length: 2)
            port = UInt16(bigEndian: port)
            print("\(String(describing: domain)):\(port)")
            
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
            resData.append(0x23)
            resData.append(0x28)
            sock.write(resData, withTimeout: 10, tag: 505)
            sock.readData(withTimeout: 10, tag: 506)
        }
    }

}

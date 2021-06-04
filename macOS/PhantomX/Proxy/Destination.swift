//
//  Destination.swift
//  PhantomX
//
//  Created by Rake Yang on 2021/5/31.
//  Copyright © 2021 BinaryParadise. All rights reserved.
//

import Foundation

/// 地址类型
enum AType: UInt8 {
    case ipv4   = 0x01
    case ipv6   = 0x04
    case domain = 0x03
}

/// 目标地址
struct Destination {
    var atyp: AType
    var addr: Data
    var port: Int
    
    init(data: Data) {
        atyp = AType(rawValue: data[3]) ?? .ipv4
        if atyp == .domain {//域名：路由规则
            addr = data.subdata(in: 5..<data.count-2)
        } else if atyp == .ipv6 {
            addr = data.subdata(in: 5..<11)
        } else if atyp == .ipv4 {
            addr = data.subdata(in: 4..<8).map({ b in
                String(b)
            }).joined(separator: ".").data(using: .utf8) ?? Data()
        } else {
            addr = Data()
        }
        port = Int(data.subdata(in: Data.Index(data.count-2)..<data.count).toUInt16())
    }
    
    var description:String {
        switch atyp {
        case .ipv4:
            return addr.string(encoding: .utf8) ?? "未知"
        case .ipv6:
            return addr.string(encoding: .utf8) ?? "未知"
        case .domain:
            return addr.string(encoding: .utf8) ?? "未知"
        }
    }
}

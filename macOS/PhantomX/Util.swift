//
//  Util.swift
//  PhantomX
//
//  Created by Rake Yang on 2020/4/4.
//  Copyright © 2020 BinaryParadise. All rights reserved.
//

import Foundation

extension UserDefaults {
    enum CacheKey: String {
        case localPacPort
    }
    
    static func getString(forKey key: CacheKey) -> String? {
        return UserDefaults.standard.string(forKey: key.rawValue)
    }
    
    static func setString(forKey key: CacheKey, value: String) -> Void {
        UserDefaults.standard.setValue(value, forKey: key.rawValue)
    }
}

extension Int {
    // MARK:- 转成 2位byte
    func toUInt16() -> [UInt8] {
        let UInt = UInt16.init(Double.init(self))
        return [UInt8(truncatingIfNeeded: UInt >> 8),UInt8(truncatingIfNeeded: UInt)]
    }
    // MARK:- 转成 4字节的bytes
    func toUInt() -> [UInt8] {
        let UInt = UInt32.init(Double.init(self))
        return [UInt8(truncatingIfNeeded: UInt >> 24),
                UInt8(truncatingIfNeeded: UInt >> 16),
                UInt8(truncatingIfNeeded: UInt >> 8),
                UInt8(truncatingIfNeeded: UInt)]
    }
    // MARK:- 转成 8位 bytes
    func toUInt8() -> [UInt8] {
        let UInt = UInt64.init(Double.init(self))
        return [UInt8(truncatingIfNeeded: UInt >> 56),
                UInt8(truncatingIfNeeded: UInt >> 48),
                UInt8(truncatingIfNeeded: UInt >> 40),
                UInt8(truncatingIfNeeded: UInt >> 32),
                UInt8(truncatingIfNeeded: UInt >> 24),
                UInt8(truncatingIfNeeded: UInt >> 16),
                UInt8(truncatingIfNeeded: UInt >> 8),
                UInt8(truncatingIfNeeded: UInt)]
    }
}

//
//  DataUtil.swift
//  PhantomX
//
//  Created by Rake Yang on 2020/4/11.
//  Copyright © 2020 BinaryParadise. All rights reserved.
//

import Foundation
import CryptoSwift
import CocoaLumberjack

let aes_key1 = "8.neverland.life"
let aes_key2 = "9.neverland.life"

class DataUtil {
    static func encrypt(data:Data) -> Array<UInt8>? {
        do {
            let aes = try AES(key: aes_key1.bytes, blockMode: ECB())
            return try aes.encrypt(data.bytes)
        } catch {
            DDLogError("\(error)")
            return nil;
        }
    }
    
    static func decrypt(data:Data) -> Array<UInt8>? {
        do {
            let aes = try AES(key: aes_key2.bytes, blockMode: ECB())
            return try aes.decrypt(data.bytes)
        } catch {
            return nil
        }
    }
}

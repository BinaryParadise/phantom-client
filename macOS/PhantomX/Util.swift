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

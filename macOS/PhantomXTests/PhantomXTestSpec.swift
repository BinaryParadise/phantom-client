//
//  PhantomXTests.swift
//  PhantomXTests
//
//  Created by Rake Yang on 2020/4/4.
//  Copyright © 2020 BinaryParadise. All rights reserved.
//

import Quick
import Nimble

@testable import PhantomX

class PhantomXTestSpec: QuickSpec {
    override func spec() {
        describe("加密解密") {
            it("AES") {
                let text = "0123456"
                let data1 = DataUtil.encrypt(data: text.data(using: .utf8)!)
                let data2 = DataUtil.decrypt(data: Data.init(data1!))
                let str2 = String.init(data: Data.init(data2!), encoding: .utf8)
                expect(text).to(equal(str2))
            }
        }
    }
}

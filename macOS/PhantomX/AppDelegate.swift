//
//  AppDelegate.swift
//  PhantomX
//
//  Created by Rake Yang on 2020/4/4.
//  Copyright © 2020 BinaryParadise. All rights reserved.
//

import Cocoa
import Canary

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var statusMenu: NSMenu!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        let manager = CNManager.init()
        manager?.appKey = "com.binaryparadise.neverland"
        manager?.enableDebug = true
        manager?.baseURL = URL.init(string: "https://yuqi.neverland.life")
        manager?.startLogMonitor({ () -> [String : Any]? in
            return [:]
        })
        DDLog.add(DDTTYLogger.sharedInstance)
        DDLogInfo(NSHomeDirectory())
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        ProxyLauncher.setSystemProxy(mode: .restore)
    }


}


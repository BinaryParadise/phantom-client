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
        manager?.appKey = "9ae688845f4c2fe28f4a4b1f83c6ab03"
        manager?.baseURL = URL.init(string: "http://frontend.xinc818.com")
        manager?.startLogMonitor({ () -> [String : Any]? in
            return [:]
        })
        DDLog.add(DDTTYLogger.sharedInstance!)
        DDLogDebug(NSHomeDirectory())
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        ProxyLauncher.setSystemProxy(mode: .restore)
    }


}


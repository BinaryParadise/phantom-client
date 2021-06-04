//
//  AppDelegate.swift
//  PhantomX
//
//  Created by Rake Yang on 2020/4/4.
//  Copyright © 2020 BinaryParadise. All rights reserved.
//

import Cocoa
import CocoaLumberjack

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var statusMenu: NSMenu!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application        
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        ProxyLauncher.setSystemProxy(mode: .restore)
    }


}


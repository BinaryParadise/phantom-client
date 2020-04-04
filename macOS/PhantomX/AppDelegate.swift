//
//  AppDelegate.swift
//  PhantomX
//
//  Created by Rake Yang on 2020/4/4.
//  Copyright © 2020 BinaryParadise. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {



    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        print(Bundle.main.bundlePath)
        ProxyLauncher.startHttpServer()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        ProxyLauncher.setSystemProxy(mode: .restore)
    }


}


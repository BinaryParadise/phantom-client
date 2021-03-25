//
//  MenuController.swift
//  PhantomX
//
//  Created by Rake Yang on 2020/4/4.
//  Copyright © 2020 BinaryParadise. All rights reserved.
//

import Cocoa
import CocoaAsyncSocket
import CocoaLumberjack

let menuController = (NSApplication.shared.delegate as? AppDelegate)?.statusMenu.delegate as! MenuController

class MenuController: NSObject {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    @IBOutlet weak var statusMenu: NSMenu!

    override func awakeFromNib() {
        statusItem.menu = statusMenu
        statusItem.image = NSImage.init(named: "statusBar")
    }
}

extension MenuController: NSMenuDelegate {
    @IBAction func proxyClicked(_ menuItem: NSMenuItem!) {
        if menuItem.state == .off {
            ProxyLauncher.shared.startProxy()
            menuItem.title = "关闭代理"
            menuItem.state = .on
        } else {
            ProxyLauncher.shared.stopProxy()
            menuItem.title = "开启代理"
            menuItem.state = .off
        }
    }
    
    @IBAction func quitClicked(_ menuItem: NSMenuItem!) {
        NSApplication.shared.terminate(self)
    }
}

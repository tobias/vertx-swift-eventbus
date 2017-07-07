//
//  ViewController.swift
//  vertx-ios-swift-client
//
//  Created by Garri Adrian Nablo on 7/1/17.
//
//

import UIKit

class ViewController: UIViewController {
    
    fileprivate let eventBus = EventBus(host: "localhost", port: 7001)

    override func viewDidLoad() {
        super.viewDidLoad()
        connect()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

// MARK: - Private
extension ViewController {
    
    fileprivate func connect() {
        do {
            try eventBus.connect()
            register()
        } catch let error {
            print("Error Connecting: " + error.localizedDescription)
        }
    }
    
    fileprivate func register() {
        do {
            _ = try eventBus.register(address: "test.echo.responses") { message in
                print("Event Bus Message: \(message.body)")
            }
        } catch let error {
            print("Error Registering: " + error.localizedDescription)
        }
    }
}


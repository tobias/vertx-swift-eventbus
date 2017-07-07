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
    
    fileprivate func reply(to message: Message, counter: Int) {
        guard counter < 7 else { return }
        
        print("ping-pong: count is \(counter)")
        
        do {
            try message.reply(body: ["counter": counter + 1]) { response in
                guard let message = response.message else { return }
                
                self.reply(to: message, counter: message.body["counter"].intValue)
            }
        } catch let error {
            print("Error Sending \(counter) Reply: " + error.localizedDescription)
        }
    }
}

// MARK: - IBAction
extension ViewController {
    
    @IBAction fileprivate func replyAction() {
        do {
            _ = try eventBus.send(to: "test.ping-pong", body: ["counter": 0]) { response in
                guard let message = response.message else { return }
                
                self.reply(to: message, counter: message.body["counter"].intValue)
            }
        } catch let error {
            print("Error Sending first message: " + error.localizedDescription)
        }
    }
    
    // MARK: Send
    @IBAction fileprivate func sendAction() {
        do {
            _ = try eventBus.send(to: "test.echo", body: ["foo": "bar"]) { response in
                guard let body = response.message?.body else { return }
                
                print("Send Response: \(body)")
            }
        } catch let error {
            print("Error Sending in \(#function): " + error.localizedDescription)
        }
    }
    
    @IBAction fileprivate func sendWithHeadersAction() {
        do {
            _ = try eventBus.send(to: "test.echo",
                                  body: ["foo": "bar"],
                                  headers: ["ham": "biscuit"]) { response in
                guard let body = response.message?.body else { return }
                
                print("Send Response: \(body)")
            }
        } catch let error {
            print("Error Sending in \(#function): " + error.localizedDescription)
        }
    }
    
    // MARK: Publish
    @IBAction fileprivate func publishAction() {
        do {
            _ = try eventBus.publish(to: "test.echo", body: ["foo": "bar"])
        } catch let error {
            print("Error Publishing in \(#function): " + error.localizedDescription)
        }
    }
    
    @IBAction fileprivate func publishWithHeadersAction() {
        do {
            _ = try eventBus.publish(to: "test.echo",
                                     body: ["foo": "bar"],
                                     headers: ["ham": "biscuit"])
        } catch let error {
            print("Error Publishing in \(#function): " + error.localizedDescription)
        }
    }
}

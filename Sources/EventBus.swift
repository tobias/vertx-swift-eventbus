/**
 * Copyright Red Hat, Inc 2016
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

import Dispatch
import Foundation
import Socket
import SwiftyJSON

/// Provides a connection to a remote [TCP EventBus Bridge](https://github.com/vert-x3/vertx-tcp-eventbus-bridge).
public class EventBus {
    private let host: String
    private let port: Int32
    private let pingInterval: Int
    
    private let readQueue = DispatchQueue(label: "read")
    private let workQueue = DispatchQueue(label: "work", attributes: [.concurrent])

    private var socket: Socket?
        
    private var errorHandler: ((Error) -> ())? = nil
    private var handlers = [String: [String: Registration]]()
    private var replyHandlers = [String: (Response) -> ()]()
    private let replyHandlersMutex = Mutex(recursive: true)
    
    func readLoop() {
        if connected() {
            readQueue.async(execute: {
                                self.readMessage()
                                self.readLoop()
                            })
        }
    }

    func pingLoop() {
        if connected() {
            DispatchQueue.global()
              .asyncAfter(deadline: DispatchTime.now()
                            + DispatchTimeInterval.milliseconds(self.pingInterval),
                          execute: {
                              self.ping()
                              self.pingLoop()
                          })
        }
    }

    func readMessage() {
        guard let socket = self.socket else {
            handleError(Error.disconnected(cause: nil))

            return
        }
        do {
            if let msg = try Util.read(from: socket) {
                dispatch(msg)
            }
        } catch let error {
            disconnect()
            handleError(Error.disconnected(cause: error))
        }
    }

    func handleError(_ error: Error) {
        if let h = self.errorHandler {
            h(error)
        }
    }

    func dispatch(_ json: JSON) {
        guard let address = json["address"].string else {
            if let type = json["type"].string,
               type == "err" {
                handleError(Error.serverError(message: json["message"].string!))
            }
            
            // ignore unknown messages
            
            return
        }

        let msg = Message(basis: json, eventBus: self)
        if let handlers = self.handlers[address] {
            if (msg.isSend) {
                if let registration = handlers.values.first {
                    workQueue.async(execute: { registration.handler(msg) })
                }
            } else {
                for registration in handlers.values {
                    workQueue.async(execute: { registration.handler(msg) })
                }
            }
        } else if let handler = self.replyHandlers[address] {
            workQueue.async(execute: { handler(Response(message: msg)) })
        }
    }

    func send(_ message: JSON) throws {
        guard let m = message.rawString() else {
            throw Error.invalidData(data: message)
        }
        
        try send(m)
    }

    func send(_ message: String) throws {
        guard let socket = self.socket else {
            throw Error.disconnected(cause: nil)
        }
        do {
            try Util.write(from: message, to: socket)
        } catch let error {
            disconnect()
            throw Error.disconnected(cause: error)
        }
    }

    func ping() {
        do {
            try send(JSON(["type": "ping"]))
        } catch let error {
            if let e = error as? Error {
                handleError(e)
            }
            // else won't happen
        }
    }

    func uuid() -> String {
        return NSUUID().uuidString
    }

    // public API

    /// Creates a new EventBus instance.
    ///
    /// Note: a new EventBus instance *isn't* connected to the bridge automatically. See `connect()`.
    ///
    /// - parameters:
    ///   - <#host#>: host running the bridge
    ///   - <#port#>: port the bridge is listening on
    ///   - <#pingEvery#>: interval (in ms) to ping the bridge to ensure it is still up (default: `5000`)
    /// - returns: a new EventBus
    public init(host: String, port: Int, pingEvery: Int = 5000) {
        self.host = host
        self.port = Int32(port)
        self.pingInterval = pingEvery
    }

    /// Connects to the remote bridge.
    ///
    /// Any already registered message handlers will be (re)connected.
    ///
    /// - throws: `Socket.Error` if connecting fails
    public func connect() throws {
        self.socket = try Socket.create()
        try self.socket!.connect(to: self.host, port: self.port)
        readLoop()
        ping() // ping once to get this party started
        pingLoop()

        for handlers in self.handlers.values {
            for registration in handlers.values {
                let _ = try register(address: registration.address,
                                     id: registration.id,
                                     headers: registration.headers,
                                     handler: registration.handler)
            }
        }
    }

    /// Disconnects from the remote bridge.
    public func disconnect() {
        if let s = self.socket {
            for handlers in self.handlers.values {
                for registration in handlers.values {
                    // We don't care about errors here, since we're
                    // not going to be receiving messages anyway. We
                    // unregister as a convenience to the bridge.
                    let _ = try? unregister(address: registration.address,
                                            id: registration.id,
                                            headers: registration.headers)
                }
            }   
            s.close()
            self.socket = nil
        }
    }

    /// Signals the current state of the connection.
    ///
    /// - returns: `true` if connected to the remote bridge, `false` otherwise
    public func connected() -> Bool {
        if let _ = self.socket {
            
            return true
        }

        return false
    }

    /// Sends a message to an EventBus address.
    ///
    /// If the remote handler will reply, you can provide a callback
    /// to handle that reply. If no reply is received within the
    /// specified timeout, a `Response` that responds with `false` to
    /// `timeout()` will be passed.
    ///
    /// - parameters:
    ///   - <#to#>: the address to send the message to
    ///   - <#body#>: the body of the message
    ///   - <#headers#>: headers to send with the message (default: `[String: String]()`)
    ///   - <#replyTimeout#>: the timeout (in ms) to wait for a reply if a reply callback is provided (default: `30000`)
    ///   - <#callback#>: the callback to handle the reply or timeout `Response` (default: `nil`)
    /// - throws: `Error.invalidData(data:)` if the given `body` can't be converted to JSON
    /// - throws: `Error.disconnected(cause:)` if not connected to the remote bridge
    public func send(to address: String,
                     body: [String: Any],
                     headers: [String: String]? = nil,
                     replyTimeout: Int = 30000, // 30 seconds
                     callback: ((Response) -> ())? = nil) throws {
        var msg: [String: Any] = ["type": "send", "address": address, "body": body, "headers": headers ?? [String: String]()]

        if let cb = callback {
            let replyAddress = uuid()
            let timeoutAction = DispatchWorkItem() {
                self.replyHandlersMutex.lock()
                defer {
                    self.replyHandlersMutex.unlock()
                }
                if let _ = self.replyHandlers.removeValue(forKey: replyAddress) {
                    cb(Response.timeout())
                }
            }
  
            replyHandlers[replyAddress] = {[unowned self] (r) in
                self.replyHandlersMutex.lock()
                defer {
                    self.replyHandlersMutex.unlock()
                }
                if let _ = self.replyHandlers.removeValue(forKey: replyAddress) {
                    timeoutAction.cancel()
                    cb(r)
                }
            }

            msg["replyAddress"] = replyAddress
                
            DispatchQueue.global()
              .asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.milliseconds(replyTimeout),
                          execute: timeoutAction)
        }
        
        try send(JSON(msg))
    }

    /// Publishes a message to the EventBus.
    ///
    /// - parameters:
    ///   - <#to#>: the address to send the message to
    ///   - <#body#>: the body of the message
    ///   - <#headers#>: headers to send with the message (default: `[String: String]()`)
    /// - throws: `Error.invalidData(data:)` if the given `body` can't be converted to JSON
    /// - throws: `Error.disconnected(cause:)` if not connected to the remote bridge    
    public func publish(to address: String,
                        body: [String: Any],
                        headers: [String: String]? = nil) throws {
        try send(JSON(["type": "publish",
                       "address": address,
                       "body": body,
                       "headers": headers ?? [String: String]()] as [String: Any]))
    }

    /// Registers a closure to receive messages for the given address.
    ///
    /// - parameters:
    ///   - <#address#>: the address to listen to
    ///   - <#id#>: the id for the registration (default: a random uuid)
    ///   - <#headers#>: headers to send with the register request (default: `[String: String]()`)
    ///   - <#handler#>: the closure to handle each `Message`
    /// - returns: an id for the registration that can be used to unregister it
    /// - throws: `Error.disconnected(cause:)` if not connected to the remote bridge    
    public func register(address: String,
                         id: String? = nil,
                         headers: [String: String]? = nil,
                         handler: @escaping (Message) -> ()) throws -> String {
        let _id = id ?? uuid()
        let _headers = headers ?? [String: String]()
        let registration = Registration(address: address, id: _id, handler: handler, headers: _headers)
        if let _ = self.handlers[address] {
            self.handlers[address]![_id] = registration
        } else {
            self.handlers[address] = [_id : registration]
            try send(JSON(["type": "register", "address": address, "headers": _headers]))
        }

        return _id
    }

    /// Registers a closure to receive messages for the given address.
    ///
    /// - parameters:
    ///   - <#address#>: the address to remove the registration from
    ///   - <#id#>: the id for the registration 
    ///   - <#headers#>: headers to send with the unregister request (default: `[String: String]()`)
    /// - returns: `true` if something was actually unregistered
    /// - throws: `Error.disconnected(cause:)` if not connected to the remote bridge
    public func unregister(address: String, id: String, headers: [String: String]? = nil) throws -> Bool {
        guard var handlers = self.handlers[address],
              let _ = handlers[id] else {

                  return false
              }

        handlers.removeValue(forKey: id)

        if handlers.isEmpty {
            try send(JSON(["type": "unregister", "address": address, "headers": headers ?? [String: String]()]))
        }

        return true
    }

    /// Registers an error handler that will be passed any errors that occur in async operations.
    ///
    /// Operations that can trigger this error handler are:
    /// - handling messages received from the remote bridge (can trigger `Error.disconnected(cause:)` or `Error.serverError(message:)`)
    /// - the ping operation discovering the bridge connection has closed (can trigger `Error.disconnected(cause:)`)
    ///
    /// - parameters:
    ///   - <#errorHandler#>: a closure that will be passed an `Error` when an error occurs
    public func register(errorHandler: @escaping (Error) -> ()) {
        self.errorHandler = errorHandler
    }

    // TODO: docs
    public enum Error : Swift.Error {
        case invalidData(data: JSON)
        case serverError(message: String)
        case disconnected(cause: Swift.Error?)
    }

    struct Registration {
        let address: String
        let id: String
        let handler: (Message) -> ()
        let headers: [String: String]
    }
}

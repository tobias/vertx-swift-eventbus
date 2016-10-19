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

public class EventBus {
    private let host: String
    private let port: Int32
    private let pingInterval: Int
    
    private let readQueue = DispatchQueue(label: "read")
    private let workQueue = DispatchQueue(label: "work", attributes: [.concurrent])

    private var socket: Socket?
        
    private var errorHandler: ((EventBusError) -> ())? = nil
    private var handlers = [String : [String : (Message) -> ()]]()
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
            handleError(EventBusError.disconnected(cause: nil))

            return
        }
        do {
            if let msg = try Util.read(from: socket) {
                dispatch(msg)
            }
        } catch let error {
            disconnect()
            handleError(EventBusError.disconnected(cause: error))
        }
    }

    func handleError(_ error: EventBusError) {
        if let h = self.errorHandler {
            h(error)
        }
    }

    func dispatch(_ json: JSON) {
        guard let address = json["address"].string else {
            if let type = json["type"].string,
               type == "err" {
                handleError(EventBusError.serverError(message: json["message"].string!))
            }
            
            // ignore unknown messages
            
            return
        }

        let msg = Message(basis: json, eventBus: self)
        if let h = self.handlers[address] {
            for handler in h.values {
                workQueue.async(execute: { handler(msg) })
            }
        } else if let h = self.replyHandlers[address] {
            workQueue.async(execute: { h(Response(message: msg)) })
        }
    }

    func send(_ message: JSON) throws {
        guard let m = message.rawString() else {
            throw EventBusError.invalidData(data: message)
        }
        
        try send(m)
    }

    func send(_ message: String) throws {
        guard let socket = self.socket else {
            throw EventBusError.disconnected(cause: nil)
        }
        do {
            try Util.write(from: message, to: socket)
        } catch let error {
            disconnect()
            throw EventBusError.disconnected(cause: error)
        }
    }

    func ping() {
        do {
            try send(JSON(["type": "ping"]))
        } catch let error {
            if let e = error as? EventBusError {
                handleError(e)
            }
            // else won't happen
        }
    }

    func uuid() -> String {
        return NSUUID().uuidString
    }

    // public API

    public init(host: String, port: Int, pingEvery: Int = 5000) {
        self.host = host
        self.port = Int32(port)
        self.pingInterval = pingEvery
    }

    public func connect() throws {
        self.socket = try Socket.create()
        try self.socket!.connect(to: self.host, port: self.port)
        readLoop()
        ping() // ping once to get this party started
        pingLoop()
    }

    public func disconnect() {
        if let s = self.socket {
            s.close()
            self.socket = nil
        }
    }

    public func connected() -> Bool {
        if let _ = self.socket {
            
            return true
        }

        return false
    }
    
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

    public func publish(to address: String,
                        body: [String: Any],
                        headers: [String: String]? = nil) throws {
        try send(JSON(["type": "publish",
                       "address": address,
                       "body": body,
                       "headers": headers ?? [String: String]()] as [String: Any]))
    }

    // returns an id to use when unregistering
    public func register(address: String,
                         id: String? = nil,
                         headers: [String: String]? = nil,
                         handler: @escaping ((Message) -> ())) throws -> String {
        let _id = id ?? uuid()
        if let _ = self.handlers[address] {
            self.handlers[address]![_id] = handler
        } else {
            self.handlers[address] = [_id : handler]
        }

        try send(JSON(["type": "register", "address": address, "headers": headers ?? [String: String]()])) 

        return _id
    }

    // returns true if something was actually unregistered
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

    public func register(errorHandler: @escaping (EventBusError) -> ()) {
        self.errorHandler = errorHandler
    }
}

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

// TODO: check to make sure the socket is still open
// TODO: reconnect?
// TODO: error handler
// TODO: handle replies

public enum EventBusError: Error {
    case serverError(message: String)
    case unknownMessage(message: JSON)
    case unknownError(error: Error)
}

public class EventBus {
    private let socket: Socket

    private let readQueue = DispatchQueue(label: "read")
    private let workQueue = DispatchQueue(label: "work", attributes: [.concurrent])

    private var errorHandler: ((EventBusError) -> ())? = nil
    private var handlers = [String : [String : (Message) -> ()]]()
    private var replyHandlers = [String: (Message) -> ()]()

    private var open = false

    public init(host: String, port: Int, pingEvery: Int = 5000) throws {
        self.socket = try Socket.create()
        try self.socket.connect(to: host, port: Int32(port))
        self.open = true
        readLoop()
        ping() // ping once to get this party started
        pingLoop(every: pingEvery)
    }

    func readLoop() {
        if self.open {
            readQueue.async(execute: {
                                self.readMessage()
                                self.readLoop()
                            })
        }
    }

    func pingLoop(every: Int) {
        if self.open {
            DispatchQueue.global()
              .asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.milliseconds(every),
                          execute: {
                              self.ping()
                              self.pingLoop(every: every)
                          })
        }
    }

    func readMessage() {
        do {
            if let msg = try Util.read(from: self.socket) {
                dispatch(msg)
            }
        } catch let error {
            handleError(EventBusError.unknownError(error: error))
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
            } else {
                handleError(EventBusError.unknownMessage(message: json))
            }

            return
        }

        let msg = Message(basis: json, eventBus: self)
        if let h = self.handlers[address] {
            for handler in h.values {
                workQueue.async(execute: { handler(msg) })
            }
        } else if let h = self.replyHandlers[address] {
            workQueue.async(execute: { h(msg) })
        }
    }

    func send(_ message: JSON) throws {
        try Util.write(from: message, to: self.socket)
    }

    func send(_ message: String) throws {
        try Util.write(from: message, to: self.socket)
    }

    func ping() {
        do {
            try send(JSON(["type": "ping"]))
        } catch let error {
            handleError(EventBusError.unknownError(error: error))
        }
    }

    func uuid() -> String {
        return NSUUID().uuidString
    }

    public func send(to address: String,
                     body: [String: Any],
                     headers: [String: String]? = nil,
                     callback: ((Message) -> ())? = nil) throws {
        var msg: [String: Any] = ["type": "send", "address": address, "body": body, "headers": headers ?? [String: String]()]

        if let cb = callback {
            let replyAddress = uuid()
            replyHandlers[replyAddress] = {[unowned self] (m) in
                cb(m)
                self.replyHandlers[replyAddress] = nil
            }

            msg["replyAddress"] = replyAddress
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
    public func register(address: String, id: String? = nil, handler: @escaping ((Message) -> ())) throws -> String {
        let _id = id ?? uuid()
        if let _ = self.handlers[address] {
            self.handlers[address]![_id] = handler
        } else {
            self.handlers[address] = [_id : handler]
        }

        try send(JSON(["type": "register", "address": address])) //TODO: headers

        return _id
    }

    // returns true if something was actually unregistered
    public func unregister(address: String, id: String) throws -> Bool {
        guard var handlers = self.handlers[address],
              let _ = handlers[id] else {

                  return false
              }

        handlers.removeValue(forKey: id)

        if handlers.isEmpty {
            try send(JSON(["type": "unregister", "address": address])) //TODO: headers
        }

        return true
    }

    public func register(errorHandler: @escaping (EventBusError) -> ()) {
        self.errorHandler = errorHandler
    }


    public func close() {
        if self.open {
            self.socket.close()
            self.open = false
        }
    }

}

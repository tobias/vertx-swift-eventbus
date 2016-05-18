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

public class EventBus {
    private let socket: Socket

    private let readQueue = dispatch_queue_create("read", DISPATCH_QUEUE_SERIAL)
    private let workQueue = dispatch_queue_create("work", DISPATCH_QUEUE_CONCURRENT)
    
    private var handlers = [String : [String : (JSON) -> ()]]()

    private var open = false
    
    public init(host: String, port: Int, pingEvery: Int = 5000) throws {
        self.socket = try Socket.create()
        try self.socket.connect(to: host, port: Int32(port))
        readLoop()
        self.open = true
        ping() // ping once to get this party started
        pingLoop(every: pingEvery)
    }

    func readLoop() {
        if self.open {
            dispatch_async(readQueue!, {
                          [unowned self] in
                               self.readMessage()
                               self.readLoop()
                })
        }
    }

    func pingLoop(every: Int) {
        if self.open {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                         Int64(every) * Int64(NSEC_PER_MSEC)),
                           workQueue!, {
                          [unowned self] in
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
            //TODO: betterer
            print("read failed: \(error)")
        }
    }

    func dispatch(_ json: JSON) {
        guard let address = json["address"].string else {
            print("Invalid message, ignoring: \(json)")
            return
        }

        guard let handlers = self.handlers[address] else {
            print("no handlers for \(address), ignoring: \(json)")
            return
        }

        for handler in handlers.values {
            dispatch_async(workQueue!, { handler(json) })
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
            //TODO: better
            print("ping failed: \(error)")
        }
    }

    // returns an id to use when unregistering
    public func register(address: String, id: String? = nil, handler: (JSON) -> ()) throws -> String {
        let _id = id ?? NSUUID().UUIDString
        if let _ = self.handlers[address] {
            self.handlers[address]![_id] = handler
        } else {
            self.handlers[address] = [_id : handler]
        }
        
        try send(JSON(["type": "register", "address": address])) //TODO: headers

        return _id
    }

    // returns true if something was actually unregistered
    public func unregister(address: String, id: String) throws -> Boolean {
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

    public func close() {
        if self.open {
            self.socket.close()
            self.open = false
        }
    }
    
}

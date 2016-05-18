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
import Socket
import SwiftyJSON
import VertxEventBus

class TestServer {
    let port: Int

    private var messages = [String: [JSON]]()

    private var clientSockets = [Socket]()
    
    private var socket: Socket?
    private let acceptQueue = dispatch_queue_create("TestServer::accept", DISPATCH_QUEUE_CONCURRENT)
    private let readQueue = dispatch_queue_create("TestServer::read", DISPATCH_QUEUE_SERIAL)

    init(on port: Int = 9876) {
        self.port = port
        listen()
    }

    subscript(type: String) -> [JSON] {
        if let msgs = messages[type] {
            return msgs
        }

        return []
    }

    func listen() {
        do {
            self.socket = try Socket.create()
        } catch let error {
            print("Failed to create socket: \(error)")
            return
        }
        
        guard let sock = self.socket else {
            print("No socket!")
            return
        }
        
        try! sock.listen(on: port)
        dispatch_async(acceptQueue!) { [unowned self] in
            while sock.isListening {
                do {
                    let clientSock = try sock.acceptClientConnection()
                    self.clientSockets.append(clientSock)
                    self.readLoop(clientSock)
                } catch let error {
                    if error is Socket.Error &&
                         (error as! Socket.Error).errorCode == Int32(Socket.SOCKET_ERR_ACCEPT_FAILED) {
                        return
                    }
                    print("Accept failed: \(error)")
                }
            }
        }
    }
    
    func readLoop(_ sock: Socket) {
        dispatch_async(readQueue!) { [unowned self] in
            do {
                if let msg = try Util.read(from: sock),
                   let type = msg["type"].string {
                    //print("MSG \(msg)")
                    if let _ = self.messages[type] {
                        self.messages[type]!.append(msg)
                    } else {
                        self.messages[type] = [msg]
                    }        
                    self.readLoop(sock)
                }
            } catch let error {
                print("Read failed: \(error)")
            }
        }
    }

    func reset() {
        messages = [:]
    }

    func close() {
        for s in self.clientSockets {
            s.close()
        }
        
        if let s = self.socket {
            s.close()
        }
    }
     
    func send(_ data: JSON) {
        for s in self.clientSockets {
            do {
                if try s.isReadableOrWritable().writable {
                    try Util.write(from: data, to: s)
                }
            } catch let error {
                print("Write failed: \(error)")
            }
        }
    }
}

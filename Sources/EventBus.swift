import Dispatch
import Foundation
import Socket
import SwiftyJSON

public class EventBus {
    private let socket: Socket

    private let readQueue = dispatch_queue_create("read", DISPATCH_QUEUE_SERIAL)
    private let pingQueue = dispatch_queue_create("ping", DISPATCH_QUEUE_SERIAL)
    private let handlerQueue = dispatch_queue_create("handle", DISPATCH_QUEUE_CONCURRENT)
    
    private var handlers = [String : [(JSON) -> ()]]()
    
    public init(host: String, port: Int32) throws {
        self.socket = try Socket.create()
        try self.socket.connect(to: host, port: port)
        readLoop()
        ping()
        pingLoop(every: 5)
    }

    func readLoop() {
        dispatch_async(readQueue!, {
                      [unowned self] in
                           self.readMessage()
                           self.readLoop()
            })
    }

    func pingLoop(every: UInt64) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                     Int64(every * NSEC_PER_SEC)),
                       pingQueue!, {
                      [unowned self] in
                           self.ping()
                           self.pingLoop(every: every)
            })
    }
    
    func readMessage() {
        let data = NSMutableData()
        do {
            let cnt = try self.socket.read(into: data)
            var totalRead: Int32 = 0
            if cnt > 0 {
                totalRead += cnt
                
                // read until we at least have the size
                while totalRead < 4 {
                    totalRead += try self.socket.read(into: data)
                }

                let msgSize = bytesToInt(UnsafeBufferPointer<UInt8>(start: UnsafePointer<UInt8>(data.bytes),
                                                                    count: 4))

                // read until we have a full message
                while totalRead < msgSize + 4 {
                    totalRead += try self.socket.read(into: data)
                }

                // convert message to string and dispatch
                let json = JSON(data: data.subdata(with: NSRange(location: 4, length: Int(msgSize))))
                dispatch(json)
            }
        } catch {
            //TODO: betterer
            print("BOOM")
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

        for handler in handlers {
            dispatch_async(handlerQueue!, { handler(json) })
        }
    }
    
    func bytesToInt(_ value: UnsafeBufferPointer<UInt8>) -> Int32 {
        var result: Int32 = 0
        
        for n in 0..<4 {
            result = result | (Int32(value[n]) << (8 * (3 - n)))
        }

        return result
    }
    
    func intToBytes(_ value: Int32) -> [UInt8] {
        var bytes = [UInt8]()
        
        for x in [3,2,1,0] {
            bytes.append(UInt8(value >> Int32(x * 8)))
        }
        
        return bytes
    }

    func send(_ message: JSON) throws {
        guard let m = message.rawString() else {
            // TODO: throw
            return
        }
                    
        try send(m)
    }
    
    func send(_ message: String) throws {
        print("SENDING \(message)")
        
        var data = [UInt8]()
        
        //write the size as 4 bytes, big-endian
        data += intToBytes(Int32(message.utf8.count))
        data += message.utf8
        
        try self.socket.write(from: data, bufSize: data.count)
    }

    func ping() {
        do {
            try send(JSON(["type": "ping"]))
        } catch {
            //TODO: better
            print("ping failed!")
        }
    }
    
    public func register(address: String, handler: (JSON) -> ()) throws {
        if let _ = self.handlers[address] {
            self.handlers[address]!.append(handler)
        } else {
            self.handlers[address] = [handler]
        }
        
        try send(JSON(["type": "register", "address": address])) //TODO: headers
    }

    public func unregister(address: String, handler: (JSON) -> ()) throws {
    }
    
}

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

import Foundation
import SwiftyJSON
import XCTest

@testable import VertxEventBus

class EventBusTests: XCTestCase {

    static var allTests: [(String, (EventBusTests) -> () throws -> Void)] {
        return [("testRegister", testRegister),
                ("testRemoteReply", testRemoteReply),
                //("testLocalReply", testLocalReply),
                ("testSend", testSend),
                ("testSendWithHeaders", testSendWithHeaders),
                ("testPublish", testPublish),
                ("testPublishWithHeaders", testPublishWithHeaders),
                ("testErrorOnSend", testErrorOnSend)]}

    var eb: EventBus? = nil

    override func setUp() {
        super.setUp()
        do {
            self.eb = try EventBus(host: "localhost", port: 7001)
        } catch let error {
            print("Failed to open eventbus: \(error)")
        }
    }

    override func tearDown() {
        if let eb = self.eb {
            eb.close()
        }
        super.tearDown()
    }

    func wait(ms: UInt32) {
        usleep(ms * 1000)
    }

    func wait(s: UInt32) {
        wait(ms: s * 1000)
    }

    func testRegister() throws {
        var receivedMsgs = [Message]()

        let _ = try self.eb!.register(address: "test.time") { msg in
            receivedMsgs.append(msg)
        }
        wait(s: 2)
        XCTAssert(!receivedMsgs.isEmpty)
        if let msg = receivedMsgs.first {
            XCTAssert(msg.body["now"] != nil)
        }

    }

    func testRemoteReply() throws {
        var receivedMsgs = [Message]()

        try self.eb!.send(to: "test.echo", body: ["foo": "bar"], callback: { m in
                              receivedMsgs.append(m)
                          })
        wait(s: 2)
        XCTAssert(!receivedMsgs.isEmpty)
        if let msg = receivedMsgs.first {
            XCTAssert(msg.body["original-body"]["foo"] == "bar")
        }
    }

    func testLocalReply() throws {
        var receivedMsgs = [Message]()

        try self.eb!.send(to: "test.ping-pong", body: ["counter": 0],
                          callback: { m in
                              receivedMsgs.append(m)
                              let count = m.body["counter"].intValue
                              print("ping-pong: count is \(count)")
                              do {
                                  try m.reply(body: ["counter": count + 1],
                                              callback: { m in
                                                  do {
                                                      receivedMsgs.append(m)
                                                      let count = m.body["counter"].intValue
                                                      print("ping-pong: count is \(count)")
                                                      try m.reply(body: ["counter": count + 1],
                                                                  callback: { m in
                                                                      let count = m.body["counter"].intValue
                                                                      print("ping-pong: count is \(count)")
                                                                      receivedMsgs.append(m)
                                                                      do {
                                                                          try m.reply(["counter": count + 1])
                                                                      } catch let error {
                                                                          XCTFail(String(describing: error))
                                                                      }
                                                                  })
                                                  } catch let error {
                                                      XCTFail(String(describing: error))
                                                  }
                                              })
                              } catch let error {
                                  XCTFail(String(describing: error))
                              }
                          })
        wait(s: 2)
        XCTAssert(receivedMsgs.count == 3)
        for (idx, msg) in receivedMsgs.enumerated() {
            XCTAssert(msg.body["counter"].intValue == idx * 2 + 1)
        }
    }

    func testSend() throws {
        var receivedMsgs = [Message]()

        let _ = try self.eb!.register(address: "test.echo.responses") { msg in
            receivedMsgs.append(msg)
        }
        try self.eb!.send(to: "test.echo", body: ["foo": "bar"])
        wait(s: 2)
        XCTAssert(!receivedMsgs.isEmpty)
        if let msg = receivedMsgs.first {
            XCTAssert(msg.body["original-body"]["foo"] == "bar")
        }
    }

    func testSendWithHeaders() throws {
        var receivedMsgs = [Message]()

        let _ = try self.eb!.register(address: "test.echo.responses") { msg in
            receivedMsgs.append(msg)
        }
        try self.eb!.send(to: "test.echo", body: ["foo": "bar"], headers: ["ham": "biscuit"])
        wait(s: 2)
        XCTAssert(!receivedMsgs.isEmpty)
        if let msg = receivedMsgs.first {
            XCTAssert(msg.body["original-body"]["foo"] == "bar")
            XCTAssert(msg.body["original-headers"]["ham"] == "biscuit")
        }
    }

    func testPublish() throws {
        var receivedMsgs = [Message]()

        let _ = try self.eb!.register(address: "test.echo.responses") { msg in
            receivedMsgs.append(msg)
        }
        try self.eb!.publish(to: "test.echo", body: ["foo": "bar"])
        wait(s: 2)
        XCTAssert(!receivedMsgs.isEmpty)
        if let msg = receivedMsgs.first {
            XCTAssert(msg.body["original-body"]["foo"] == "bar")
        }
    }

    func testPublishWithHeaders() throws {
        var receivedMsgs = [Message]()

        let _ = try self.eb!.register(address: "test.echo.responses") { msg in
            receivedMsgs.append(msg)
        }
        try self.eb!.publish(to: "test.echo", body: ["foo": "bar"], headers: ["ham": "biscuit"])
        wait(s: 2)
        XCTAssert(!receivedMsgs.isEmpty)
        if let msg = receivedMsgs.first {
            XCTAssert(msg.body["original-body"]["foo"] == "bar")
            XCTAssert(msg.body["original-headers"]["ham"] == "biscuit")
        }
    }

    func testErrorOnSend() throws {
    }
}

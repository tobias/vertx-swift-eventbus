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
                ("testLocalReply", testLocalReply),
                ("testSend", testSend),
                ("testTimeoutOnSendReply", testTimeoutOnSendReply),
                ("testReplyBeatsTimeoutOnSend", testReplyBeatsTimeoutOnSend),
                ("testSendWithHeaders", testSendWithHeaders),
                ("testPublish", testPublish),
                ("testPublishWithHeaders", testPublishWithHeaders),
                ("testErrorOnSend", testErrorOnSend)]}

    var eb: EventBus? = nil

    override func setUp() {
        super.setUp()
        do {
            self.eb = EventBus(host: "localhost", port: 7001)
            try self.eb!.connect()
        } catch let error {
            print("Failed to open eventbus: \(error)")
        }
    }

    override func tearDown() {
        if let eb = self.eb {
            eb.disconnect()
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
        var results = [Message]()

        let _ = try self.eb!.register(address: "test.time") { res in
            results.append(res)
        }
        wait(s: 2)
        XCTAssert(!results.isEmpty)
        if let res = results.first {
            XCTAssert(res.body["now"] != nil)
        }

    }

    func testRemoteReply() throws {
        var results = [Response]()

        try self.eb!.send(to: "test.echo", body: ["foo": "bar"], callback: { m in
                              results.append(m)
                          })
        wait(s: 2)
        XCTAssert(!results.isEmpty)
        if let res = results.first,
           let msg = res.message {
            XCTAssert(msg.body["original-body"]["foo"] == "bar")
        }
    }

    func testLocalReply() throws {
        var results = [Response]()

        try self.eb!.send(to: "test.ping-pong", body: ["counter": 0],
                          callback: { m in
                              results.append(m)
                              XCTAssert(m.message != nil)
                              let count = m.message!.body["counter"].intValue
                              print("ping-pong: count is \(count)")
                              do {
                                  try m.message!
                                    .reply(body: ["counter": count + 1],
                                           callback: { m in
                                               do {
                                                   results.append(m)
                                                   XCTAssert(m.message != nil)
                                                   let count = m.message!.body["counter"].intValue
                                                   print("ping-pong: count is \(count)")
                                                   try m.message!
                                                     .reply(body: ["counter": count + 1],
                                                            callback: { m in
                                                                XCTAssert(m.message != nil)
                                                                let count = m.message!.body["counter"].intValue
                                                                print("ping-pong: count is \(count)")
                                                                results.append(m)
                                                                do {
                                                                    try m.message!.reply(["counter": count + 1])
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
        XCTAssert(results.count == 3)
        for (idx, res) in results.enumerated() {
            XCTAssert(res.message!.body["counter"].intValue == idx * 2 + 1)
        }
    }

    func testSend() throws {
        var results = [Message]()

        let _ = try self.eb!.register(address: "test.echo.responses") { res in
            results.append(res)
        }
        try self.eb!.send(to: "test.echo", body: ["foo": "bar"])
        wait(s: 2)
        XCTAssert(!results.isEmpty)
        if let res = results.first {
            XCTAssert(res.body["original-body"]["foo"] == "bar")
        }
    }

    func testTimeoutOnSendReply() throws {
        var result: Response?
        try self.eb!.send(to: "test.non-exist", body: ["what": "ever"], replyTimeout: 1) { result = $0 }
        wait(s: 2)
        guard let r = result else {
            XCTFail("Response is nil")
            return
        }
        XCTAssert(r.timedOut)
    }

    func testReplyBeatsTimeoutOnSend() throws {
        var results = [Response]()
        try self.eb!.send(to: "test.echo", body: ["what": "ever"], replyTimeout: 1000) { results.append($0) }
        wait(s: 2)
        XCTAssert(results.count == 1)
        if let res = results.first {
            XCTAssert(!res.timedOut)
            guard let msg = res.message else {
                XCTFail("message is missing from successful result")
                return
            }
            XCTAssert(msg.body["original-body"]["what"] == "ever")
        }
    }

    func testSendWithHeaders() throws {
        var results = [Message]()

        let _ = try self.eb!.register(address: "test.echo.responses") { res in
            results.append(res)
        }
        try self.eb!.send(to: "test.echo", body: ["foo": "bar"], headers: ["ham": "biscuit"])
        wait(s: 2)
        XCTAssert(!results.isEmpty)
        if let res = results.first {
            XCTAssert(res.body["original-body"]["foo"] == "bar")
            XCTAssert(res.body["original-headers"]["ham"] == "biscuit")
        }
    }

    func testPublish() throws {
        var results = [Message]()

        let _ = try self.eb!.register(address: "test.echo.responses") { res in
            results.append(res)
        }
        try self.eb!.publish(to: "test.echo", body: ["foo": "bar"])
        wait(s: 2)
        XCTAssert(!results.isEmpty)
        if let res = results.first {
            XCTAssert(res.body["original-body"]["foo"] == "bar")
        }
    }

    func testPublishWithHeaders() throws {
        var results = [Message]()

        let _ = try self.eb!.register(address: "test.echo.responses") { res in
            results.append(res)
        }
        try self.eb!.publish(to: "test.echo", body: ["foo": "bar"], headers: ["ham": "biscuit"])
        wait(s: 2)
        XCTAssert(!results.isEmpty)
        if let res = results.first {
            XCTAssert(res.body["original-body"]["foo"] == "bar")
            XCTAssert(res.body["original-headers"]["ham"] == "biscuit")
        }
    }

    func testErrorOnSend() throws {
    }
}

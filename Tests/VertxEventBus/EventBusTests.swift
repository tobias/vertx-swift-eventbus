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
                ("testReply", testReply),
                ("testSend", testSend),
                ("testPublish", testPublish),
                ("testErrorOnSend", testErrorOnSend)]}

    var eb: EventBus? = nil
    
    override func setUp() {
        super.setUp()
        do {
            self.eb = try EventBus(host: "localhost", port: 7001, pingEvery: 100)
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
        var receivedMsgs = [JSON]()
        
        try self.eb!.register(address: "test.time") { msg in
            receivedMsgs.append(msg)
        }
        wait(s: 2)
        XCTAssert(!receivedMsgs.isEmpty)
        if let msg = receivedMsgs.first {
            XCTAssert(msg["body"]["now"] != nil)
        }
                    
    }

    func testReply() throws {
    }

    func testSend() throws {
    }

    func testPublish() throws {
    }

    func testErrorOnSend() throws {
    }
}

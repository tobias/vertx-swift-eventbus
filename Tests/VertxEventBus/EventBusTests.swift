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
	return [("testPings", testPings),
                ("testRegister", testRegister)
        ]}

    var testServer: TestServer? = nil
    var eb: EventBus? = nil
    
    override func setUp() {
        super.setUp()
        self.testServer = TestServer()
    }

    override func tearDown() {
        if let eb = self.eb {
            eb.close()
        }

        if let server = self.testServer {
            server.close()
        }
        
        super.tearDown()
    }

    func wait(ms: UInt32) {
        usleep(ms * 1000)
    }

    func wait(s: UInt32) {
        wait(ms: s * 1000)
    }
    
    func testPings() throws {
        guard let server = self.testServer else {
            XCTFail("No server!")
            return 
        }

        self.eb = try EventBus(host: "localhost", port: self.testServer!.port, pingEvery: 1100)
        wait(s: 1)
        XCTAssertEqual(server["ping"].count, 1, "first ping")
        XCTAssertEqual(server["ping"].first!, JSON(["type": "ping"]))
        wait(s: 1)
        XCTAssertEqual(server["ping"].count, 2, "periodic ping")
    }

    func testRegister() throws {
        guard let server = self.testServer else {
            XCTFail("No server!")
            return 
        }

        self.eb = try EventBus(host: "localhost", port: self.testServer!.port)
        try self.eb!.register(address: "test") { _ in }
        wait(ms: 200)
        XCTAssertEqual(server["register"].count, 1)
        XCTAssertEqual(server["register"], [JSON(["type": "register", "address": "test"])])
    }
}

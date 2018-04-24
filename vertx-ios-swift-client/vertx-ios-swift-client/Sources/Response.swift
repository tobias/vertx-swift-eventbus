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

// Unused import, but works around bug in jazzy doc tool. Without an
// import, the doc comment for the struct is ignored.
import Foundation 

/// Represents the response for a reply.
public struct Response {
    /// The message for the reply.
    ///
    /// Will be nil if `timedOut` is `true`
    public let message: Message?
    
    /// The timeout status of the reply.
    ///
    /// `message` will be nil if this is `true`.
    public var timedOut: Bool {
        if let _ = self.message {

            return false
        }

        return true
    }

    static func timeout() -> Response {
        return Response(message: nil)
    }
}






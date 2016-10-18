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

public struct Result {
    public let successful: Bool
    public let error: Error?
    public let message: Message?

    init(successful: Bool, error: Error?, message: Message?) {
        self.successful = successful
        self.error = error
        self.message = message
    }

    public init(_ error: Error) {
        self.init(successful: false, error: error, message: nil)
    }

    public init(_ message: Message) {
        self.init(successful: true, error: nil, message: message)
    }
}






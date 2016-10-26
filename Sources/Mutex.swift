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

// convenience wrapper wround pthread_mutex_t
class Mutex {
    var mutex = pthread_mutex_t()
    
    init(recursive: Bool = false) {
        var attr = pthread_mutexattr_t()
	pthread_mutexattr_init(&attr)

	if recursive {
            pthread_mutexattr_settype(&attr, Int32(PTHREAD_MUTEX_RECURSIVE))
        } else {
	    pthread_mutexattr_settype(&attr, Int32(PTHREAD_MUTEX_NORMAL))
        }
    }

    deinit {
        pthread_mutex_destroy(&mutex)
    }
    
    func lock() {
        pthread_mutex_lock(&mutex)
    }

    func unlock() {
        pthread_mutex_unlock(&mutex)
    }
    
}
    
        

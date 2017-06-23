# Copyright IBM Corporation 2016
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Makefile

# Customized from the original for this project - toby@tcrawley.org

UNAME = ${shell uname}

ifeq ($(UNAME), Darwin)
SWIFTC_FLAGS = 
LINKER_FLAGS = 
endif

ifeq ($(UNAME), Linux)
SWIFTC_FLAGS = -Xcc -fblocks
LINKER_FLAGS = -Xlinker -rpath -Xlinker .build/debug 
endif

all: run

build:
	@echo --- Running build on $(UNAME)
	@echo --- Checking swift version
	swift --version
	@echo --- Checking swiftc version
	swiftc --version
ifeq ($(UNAME), Linux)
	@echo --- Checking Linux release
	-lsb_release -d
endif
	@echo --- Invoking swift build
	swift build $(SWIFTC_FLAGS) $(LINKER_FLAGS)


refetch:
	@echo --- Removing Packages directory
	rm -rf Packages
	@echo --- Fetching dependencies
	swift package fetch

clean:
	@echo --- Cleaning Swift builds
	swift package clean

run: build
	./.build/debug/VertxEventBusExample

.PHONY: clean build refetch run 

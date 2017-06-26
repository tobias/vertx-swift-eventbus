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

ifndef BUILD_SCRIPTS_DIR
BUILD_SCRIPTS_DIR = ./scripts
endif

UNAME = ${shell uname}

TEST_SERVER_PIDFILE = test-server/target/pidfile

GIT_TAG = ${shell git describe --abbrev=0 --tags}

ifeq ($(UNAME), Darwin)
SWIFTC_FLAGS = 
LINKER_FLAGS = 
endif

ifeq ($(UNAME), Linux)
SWIFTC_FLAGS = -Xcc -fblocks
LINKER_FLAGS = -Xlinker -rpath -Xlinker .build/debug 
endif

all: build

build:
	@echo --- Running build on $(UNAME)
	@echo --- Build scripts directory: ${BUILD_SCRIPTS_DIR}
	@echo --- Checking swift version
	swift --version
	@echo --- Checking swiftc version
	swiftc --version
	@echo --- Checking git revision and branch
	-git rev-parse HEAD
	-git rev-parse --abbrev-ref HEAD
ifeq ($(UNAME), Linux)
	@echo --- Checking Linux release
	-lsb_release -d
endif
	@echo --- Invoking swift build
	swift build $(SWIFTC_FLAGS) $(LINKER_FLAGS)

Tests/LinuxMain.swift:
ifeq ($(UNAME), Linux)
	@echo --- Generating $@
	bash ${BUILD_SCRIPTS_DIR}/generate_linux_main.sh
endif

test: build Tests/LinuxMain.swift test-server/target/test-server.jar
	@echo --- Invoking tests
	${BUILD_SCRIPTS_DIR}/run-tests.sh

refetch:
	@echo --- Removing Packages directory
	rm -rf Packages
	@echo --- Fetching dependencies
	swift package fetch

clean:
	@echo --- Cleaning Swift and test-server builds
	swift package clean
	cd test-server && mvn clean
ifeq ($(UNAME), Linux)
	rm -f Tests/LinuxMain.swift
endif

run: build
	./.build/debug/VertxEventBus

test-server/target/test-server.jar:
	cd test-server && mvn package

docs: build
	@echo -- Generating docs for ${GIT_TAG}
	@echo -- Checking sourcekitten version
	sourcekitten version
	@echo -- Checking jazzy version
	jazzy --version
	sourcekitten doc --spm-module VertxEventBus > /tmp/VertxEventBus.json
	jazzy --sourcekitten-sourcefile /tmp/VertxEventBus.json                               \
	  --module VertxEventBus                                                              \
	  --author "Toby Crawley"                                                             \
	  --author_url http://tcrawley.org                                                    \
	  --github_url https://github.com/tobias/vertx-swift-eventbus                         \
	  --github-file-prefix https://github.com/tobias/vertx-swift-eventbus/tree/${GIT_TAG} \
	  --module-version ${GIT_TAG}                                                         \
	  --output docs/${GIT_TAG}

.PHONY: clean build refetch run test 

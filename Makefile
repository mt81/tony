# Xcode is not the active developer directory on every machine; point at it explicitly.
export DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
SIMULATOR ?= iPhone 18 Pro
DERIVED := build/DerivedData
APP := $(DERIVED)/Build/Products/Debug-iphonesimulator/Tony.app

.PHONY: test check-imports project build run clean

# The test command: TonyCore unit tests, plus the import rule.
test: check-imports
	swift test --package-path TonyCore

# TonyCore must stay free of UI and system-data frameworks.
check-imports:
	@if grep -rnE '^\s*(@preconcurrency\s+)?import\s+(UIKit|SwiftUI|EventKit|HealthKit)\b' TonyCore/Sources; then \
		echo "error: TonyCore must not import UIKit, SwiftUI, EventKit or HealthKit"; exit 1; \
	fi

project:
	xcodegen generate --quiet

build: project
	xcodebuild -project Tony.xcodeproj -scheme TonyApp \
		-destination 'platform=iOS Simulator,name=$(SIMULATOR)' \
		-derivedDataPath $(DERIVED) -quiet build

run: build
	xcrun simctl boot '$(SIMULATOR)' 2>/dev/null || true
	xcrun simctl install '$(SIMULATOR)' $(APP)
	xcrun simctl launch '$(SIMULATOR)' com.mt81.tony

clean:
	rm -rf build TonyCore/.build Tony.xcodeproj

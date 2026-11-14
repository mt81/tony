# Xcode is not the active developer directory on every machine; point at it explicitly.
export DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
TUIST_VERSION := 4.216.3
SIMULATOR ?= iPhone 18 Pro
DERIVED := build/DerivedData
APP := $(DERIVED)/Build/Products/Debug-iphonesimulator/Tony.app

.PHONY: test test-ui check-imports check-tuist project build run clean

# The test command: the import rule, then the unit tests of both packages.
test: check-imports
	swift test --package-path TonyCore
	swift test --package-path TonyStore
	swift test --package-path TonyPresentation

# Each layer imports only the layers below it.
IMPORT := ^\s*(@preconcurrency\s+)?import\s+

check-imports:
	@if grep -rnE '$(IMPORT)(UIKit|SwiftUI|EventKit|HealthKit)\b' TonyCore/Sources; then \
		echo "error: TonyCore must not import UIKit, SwiftUI, EventKit or HealthKit"; exit 1; \
	fi
	@if grep -rnE '$(IMPORT)(UIKit|SwiftUI|SwiftData|TonyStore|TonyDesign)\b' TonyPresentation/Sources; then \
		echo "error: TonyPresentation must not import UI frameworks, SwiftData, TonyStore or TonyDesign"; exit 1; \
	fi
	@if grep -rnE '$(IMPORT)(TonyCore|TonyStore)\b' TonyDesign/Sources; then \
		echo "error: TonyDesign draws data models and must not import TonyCore or TonyStore"; exit 1; \
	fi
	@if grep -rnE '$(IMPORT)Tony' TonyUIKit/Sources; then \
		echo "error: TonyUIKit is reusable and must not import any Tony module"; exit 1; \
	fi

# Everyone generates the project with the same Tuist.
check-tuist:
	@INSTALLED_VERSION="$$(tuist version)"; \
	if [ "$$INSTALLED_VERSION" != "$(TUIST_VERSION)" ]; then \
		echo "error: Tuist $(TUIST_VERSION) is required, found '$$INSTALLED_VERSION'"; exit 1; \
	fi

project: check-tuist
	tuist generate --no-open

build: project
	xcodebuild -workspace Tony.xcworkspace -scheme TonyApp \
		-destination 'platform=iOS Simulator,name=$(SIMULATOR)' \
		-derivedDataPath $(DERIVED) -quiet build

# Drives the app in the simulator: slower than `make test`, run it when a screen changes.
test-ui: project
	xcodebuild -workspace Tony.xcworkspace -scheme TonyApp \
		-destination 'platform=iOS Simulator,name=$(SIMULATOR)' \
		-derivedDataPath $(DERIVED) -quiet test

run: build
	xcrun simctl boot '$(SIMULATOR)' 2>/dev/null || true
	xcrun simctl install '$(SIMULATOR)' $(APP)
	xcrun simctl launch '$(SIMULATOR)' com.mt81.tony

clean:
	rm -rf build TonyCore/.build TonyStore/.build TonyPresentation/.build TonyUIKit/.build Tony.xcodeproj Tony.xcworkspace Derived

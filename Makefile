# Xcode is not the active developer directory on every machine; point at it explicitly.
export DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
PROJECT := Tony.xcodeproj
SIMULATOR ?= iPhone 18 Pro
DESTINATION := platform=iOS Simulator,name=$(SIMULATOR)
DERIVED := build/DerivedData
# MemberwiseInit is a macro package; command-line builds run its macros only with this flag.
MACROS := -skipMacroValidation
APP := $(DERIVED)/Build/Products/Debug-iphonesimulator/Tony.app

.PHONY: test test-ui check-imports build run clean

# The test command: the import rule, then the unit tests of TonyCore, TonyStore and TonyPresentation.
test: check-imports
	xcodebuild -project $(PROJECT) -scheme TonyUnitTests \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED) $(MACROS) -quiet test

# The business layer and the UI do not know each other; only the presentation layer knows both.
IMPORT := ^\s*(@preconcurrency\s+)?import\s+

check-imports:
	@if grep -rnE '$(IMPORT)(UIKit|SwiftUI|EventKit|HealthKit|TonyUI)' TonyCore; then \
		echo "error: TonyCore must not import UIKit, SwiftUI, EventKit, HealthKit or the UI modules"; exit 1; \
	fi
	@if grep -rnE '$(IMPORT)(TonyCore|TonyStore|TonyPresentation|TonyScreens)\b' TonyUIKit TonyUIModels; then \
		echo "error: the UI must not import TonyCore, TonyStore, TonyPresentation or the screens"; exit 1; \
	fi
	@if grep -rnE '$(IMPORT)(UIKit|SwiftUI|TonyUIKit)\b' TonyUIModels; then \
		echo "error: TonyUIModels is plain Swift and must not import UIKit, SwiftUI or the views"; exit 1; \
	fi
	@if grep -rnE '$(IMPORT)(UIKit|SwiftUI|SwiftData|TonyStore|TonyUIKit|TonyScreens)\b' TonyPresentation; then \
		echo "error: the reducers and data models must not import UI frameworks, SwiftData, TonyStore or the views"; exit 1; \
	fi
	@if grep -rnE '$(IMPORT)(TonyCore|TonyStore|SwiftData)\b' TonyScreens; then \
		echo "error: the screens draw data models and must not import TonyCore, TonyStore or SwiftData"; exit 1; \
	fi

build:
	xcodebuild -project $(PROJECT) -scheme TonyApp \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED) $(MACROS) -quiet build

# Drives the app in the simulator: slower than `make test`, run it when a screen changes.
test-ui:
	xcodebuild -project $(PROJECT) -scheme TonyApp \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED) $(MACROS) -quiet test

run: build
	xcrun simctl boot '$(SIMULATOR)' 2>/dev/null || true
	xcrun simctl install '$(SIMULATOR)' $(APP)
	xcrun simctl launch '$(SIMULATOR)' com.mt81.tony

clean:
	rm -rf build

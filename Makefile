.PHONY: build ci-build release-build run qr clean deploy install launch-installed open kill logs help lint bump bump-version changelog setup ensure-deps check-tools brew-deps

# Project configuration
WORKSPACE = Vimac.xcworkspace
SCHEME = Vimac
BUILD_DIR = build
APP_NAME = Vimac
APP_PATH = $(BUILD_DIR)/Build/Products/Debug/$(APP_NAME).app
TEAM_ID = 5RV873WV4N
LAST_BUILD_FILE = .last_build_commit

help: ## Show this help message
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36mmake %-15s\033[0m %s\n", $$1, $$2}

# Check if build number needs to be incremented based on git commits
auto-bump:
	@CURRENT_COMMIT=$$(git rev-parse HEAD) && \
	LAST_COMMIT=$$(cat $(LAST_BUILD_FILE) 2>/dev/null || echo "") && \
	if [ "$$CURRENT_COMMIT" != "$$LAST_COMMIT" ]; then \
		echo "New commits detected, incrementing build number..."; \
		BUILD=$$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" ViMac-Swift/Info.plist) && \
		NEXT=$$((BUILD + 1)) && \
		/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $$NEXT" ViMac-Swift/Info.plist && \
		echo "$$CURRENT_COMMIT" > $(LAST_BUILD_FILE) && \
		echo "Build number: $$BUILD → $$NEXT"; \
	else \
		echo "No new commits, build number unchanged"; \
	fi

ensure-deps:
	@$(MAKE) check-tools
	@if [ ! -d Pods ] || [ ! -d Carthage/Build ]; then \
		echo "Dependencies missing, running setup..."; \
		$(MAKE) setup; \
	fi

ifeq ($(CI),true)
BUILD_DEPS = ensure-deps
else
BUILD_DEPS = auto-bump ensure-deps
endif

XCODEBUILD_UNSIGNED = xcodebuild -workspace $(WORKSPACE) \
	-scheme $(SCHEME) \
	-derivedDataPath $(BUILD_DIR) \
	-destination 'platform=macOS,arch=arm64' \
	CODE_SIGNING_ALLOWED=NO \
	CODE_SIGNING_REQUIRED=NO \
	CODE_SIGN_IDENTITY="" \
	DEVELOPMENT_TEAM="" \
	BUILD_ENV=CI

build: $(BUILD_DEPS) ## Build the application (Debug, unsigned)
	@echo "Building $(SCHEME)..."
	@$(XCODEBUILD_UNSIGNED) \
		-configuration Debug \
		build

ci-build: ensure-deps ## CI build (Debug, unsigned; skips auto-bump)
	@echo "Building $(SCHEME) for CI..."
	@$(XCODEBUILD_UNSIGNED) \
		-configuration Debug \
		build

release-build: ensure-deps ## Release build (unsigned; for GitHub Releases)
	@echo "Building $(SCHEME) (Release)..."
	@$(XCODEBUILD_UNSIGNED) \
		-configuration Release \
		build

lint: ## Quick compile check - shows only errors and warnings
	@echo "Checking $(SCHEME) for errors..."
	@xcodebuild -workspace $(WORKSPACE) \
		-scheme $(SCHEME) \
		-configuration Debug \
		-derivedDataPath $(BUILD_DIR) \
		-destination 'platform=macOS,arch=arm64' \
		CODE_SIGNING_ALLOWED=NO \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGN_IDENTITY="" \
		DEVELOPMENT_TEAM="" \
		BUILD_ONLY_ACTIVE_ARCH=YES \
		build 2>&1 | grep -E '(error:|warning:)' || echo "✓ No errors or warnings"

run: ## Build and run the application
	@make kill 2>/dev/null || true
	@make build
	@echo "Launching $(APP_NAME)..."
	@open $(APP_PATH)

qr: ## Quick run without rebuilding
	@make kill 2>/dev/null || true
	@echo "Launching $(APP_NAME)..."
	@open $(APP_PATH)

clean: ## Clean build artifacts
	@echo "Cleaning build artifacts..."
	@xcodebuild -workspace $(WORKSPACE) \
		-scheme $(SCHEME) \
		clean
	@if [ -d $(BUILD_DIR) ]; then /usr/bin/trash $(BUILD_DIR); fi

bump: ## Increment build number (in Info.plist)
	@BUILD=$$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" ViMac-Swift/Info.plist) && \
	NEXT=$$((BUILD + 1)) && \
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $$NEXT" ViMac-Swift/Info.plist && \
	echo "Build number: $$BUILD → $$NEXT"

bump-version: ## Increment marketing version (patch: 0.3.19 → 0.3.20)
	@CURRENT=$$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" ViMac-Swift/Info.plist) && \
	NEXT=$$(echo $$CURRENT | awk -F. '{$$NF=$$NF+1; print}' OFS=.) && \
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $$NEXT" ViMac-Swift/Info.plist && \
	echo "Version: $$CURRENT → $$NEXT"

deploy: ## Build, install to /Applications, and run
	@make kill 2>/dev/null || true
	@make build
	@if [ -d /Applications/$(APP_NAME).app ]; then /usr/bin/trash /Applications/$(APP_NAME).app; fi
	@cp -r $(APP_PATH) /Applications/
	@echo "Launched $(APP_NAME) from /Applications"
	@open /Applications/$(APP_NAME).app

install: ## Install already-built app to /Applications (no build)
	@if [ ! -d "$(APP_PATH)" ]; then \
		echo "ERROR: Built app not found at: $(APP_PATH)"; \
		echo "Run: make build"; \
		exit 2; \
	fi
	@if [ -d /Applications/$(APP_NAME).app ]; then /usr/bin/trash /Applications/$(APP_NAME).app; fi
	@cp -r "$(APP_PATH)" /Applications/
	@echo "Installed $(APP_NAME) to /Applications"

launch-installed: ## Launch /Applications/Vimac.app (no build/install)
	@open /Applications/$(APP_NAME).app

archive: auto-bump ## Build a Release archive
	@echo "Archiving $(SCHEME)..."
	@mkdir -p $(BUILD_DIR)
	@xcodebuild -workspace $(WORKSPACE) \
		-scheme $(SCHEME) \
		-configuration Release \
		-derivedDataPath $(BUILD_DIR) \
		-destination 'platform=macOS,arch=arm64' \
		CODE_SIGN_STYLE=Automatic \
		DEVELOPMENT_TEAM=$(TEAM_ID) \
		-archivePath $(BUILD_DIR)/$(APP_NAME).xcarchive \
		-allowProvisioningUpdates \
		archive
	@echo "Archive created at $(BUILD_DIR)/$(APP_NAME).xcarchive"

open: ## Open workspace in Xcode
	@open $(WORKSPACE)

kill: ## Kill running instances of the app
	@pkill -f $(APP_NAME) || true

logs: ## Tail application logs
	@echo "Showing logs for $(APP_NAME)..."
	@log stream --predicate 'processImagePath contains "$(APP_NAME)"' --level debug

changelog: ## Generate changelog from last tag to HEAD
	@VERSION=$$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" ViMac-Swift/Info.plist) && \
	PREV_TAG=$$(git describe --tags --abbrev=0 2>/dev/null || echo "") && \
	if [ -z "$$PREV_TAG" ]; then \
		echo "No previous tag found. Using full history."; \
		RANGE="HEAD"; \
		FROM="initial"; \
	else \
		RANGE="$$PREV_TAG..HEAD"; \
		FROM="$$PREV_TAG"; \
	fi && \
	mkdir -p changelogs && \
	OUTFILE="changelogs/v$$VERSION.md" && \
	echo "# v$$VERSION" > "$$OUTFILE" && \
	echo "" >> "$$OUTFILE" && \
	echo "Changes since $$FROM:" >> "$$OUTFILE" && \
	echo "" >> "$$OUTFILE" && \
	git log $$RANGE --no-merges --pretty=format:"- %s" >> "$$OUTFILE" && \
	echo "" >> "$$OUTFILE" && \
	echo "" >> "$$OUTFILE" && \
	echo "Generated: $$(date +%Y-%m-%d)" >> "$$OUTFILE" && \
	echo "Wrote $$OUTFILE"

setup: ## Install dependencies (CocoaPods + Carthage)
	@echo "Installing CocoaPods dependencies..."
	@pod install
	@echo "Building Carthage dependencies..."
	@carthage build
	@echo "Setup complete! Run 'make build' to build the app."

check-tools: ## Verify required tools are installed
	@missing=0; \
	if ! command -v pod >/dev/null 2>&1; then \
		echo ""; \
		echo "ERROR: CocoaPods ('pod') is not installed."; \
		echo ""; \
		echo "Install (Ruby >= 3 recommended):"; \
		echo "  gem install cocoapods"; \
		echo ""; \
		echo "Notes:"; \
		echo "  - Avoid 'sudo gem ...' (often uses macOS system Ruby)."; \
		echo "  - If you use mise/asdf/etc, ensure that Ruby is activated in this shell."; \
		missing=1; \
	fi; \
	if ! command -v carthage >/dev/null 2>&1; then \
		echo ""; \
		echo "ERROR: Carthage ('carthage') is not installed."; \
		echo ""; \
		echo "Install:"; \
		echo "  brew install carthage"; \
		missing=1; \
	fi; \
	if [ $$missing -ne 0 ]; then \
		echo ""; \
		echo "Once installed, re-run: make setup (or make deploy)"; \
		exit 2; \
	fi

brew-deps: ## Install Homebrew deps via Brewfile (optional)
	@brew bundle --file ./Brewfile

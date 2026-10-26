VERSION   ?= 0.0.0-dev
BUNDLE_ID := com.sagenkoder.nudge
BUILD_DIR := .build
BUILD_APP := $(BUILD_DIR)/Nudge.app
DMG       := $(BUILD_DIR)/Nudge-$(VERSION).dmg
APP       := /Applications/Nudge.app
ARCHS     := --arch arm64 --arch x86_64

# Local builds sign with your Apple Development certificate so the Accessibility
# permission survives rebuilds, or ad-hoc ("-") when there is none.
# Releases pass IDENTITY="Developer ID Application: ..." and TIMESTAMP=--timestamp.
IDENTITY  ?= $(shell security find-identity -v -p codesigning 2>/dev/null | grep -m1 -o '"Apple Development[^"]*"' | tr -d '"' || true)
SIGN_AS   := $(if $(IDENTITY),$(IDENTITY),-)
TIMESTAMP ?= --timestamp=none
NOTARY    = xcrun notarytool submit --key "$(NOTARY_KEY)" --key-id "$(NOTARY_KEY_ID)" --issuer "$(NOTARY_ISSUER)" --wait

.PHONY: all build test app install uninstall release icon logs clean

all: app

build:
	swift build -c release $(ARCHS)

test:
	swift test

app: build
	rm -rf $(BUILD_APP)
	mkdir -p $(BUILD_APP)/Contents/MacOS $(BUILD_APP)/Contents/Resources
	cp "$$(swift build -c release $(ARCHS) --show-bin-path)/Nudge" $(BUILD_APP)/Contents/MacOS/Nudge
	sed 's/__VERSION__/$(VERSION)/g' Support/Info.plist > $(BUILD_APP)/Contents/Info.plist
	cp Support/AppIcon.icns $(BUILD_APP)/Contents/Resources/AppIcon.icns
	codesign --force --options runtime $(TIMESTAMP) --sign "$(SIGN_AS)" $(BUILD_APP)
	codesign --verify --strict $(BUILD_APP)
	@echo "Signed with: $(SIGN_AS)"

install: app
	@# Stop a running copy and clean up the LaunchAgent and ~/Applications copy that early versions used.
	-osascript -e 'quit app id "$(BUNDLE_ID)"' 2>/dev/null
	-launchctl bootout gui/$$(id -u)/$(BUNDLE_ID) 2>/dev/null
	rm -f $(HOME)/Library/LaunchAgents/$(BUNDLE_ID).plist
	rm -rf $(HOME)/Applications/Nudge.app
	rm -rf $(APP)
	ditto $(BUILD_APP) $(APP)
	open $(APP)
	@echo "Installed $(APP). It adds itself to Login Items on first launch."

uninstall:
	-$(APP)/Contents/MacOS/Nudge --unregister-login-item
	-osascript -e 'quit app id "$(BUNDLE_ID)"' 2>/dev/null
	rm -rf $(APP)
	-tccutil reset Accessibility $(BUNDLE_ID)
	@echo "Removed Nudge and its Accessibility permission."

# Used by the release workflow. Needs IDENTITY (Developer ID), TIMESTAMP=--timestamp,
# NOTARY_KEY (path to the App Store Connect .p8), NOTARY_KEY_ID and NOTARY_ISSUER.
# The app and the DMG are notarized and stapled separately, so both open offline.
release: app
	ditto -c -k --keepParent $(BUILD_APP) $(BUILD_DIR)/Nudge-notarize.zip
	$(NOTARY) $(BUILD_DIR)/Nudge-notarize.zip
	xcrun stapler staple $(BUILD_APP)
	rm -rf $(BUILD_DIR)/dmg $(DMG)
	mkdir -p $(BUILD_DIR)/dmg
	ditto $(BUILD_APP) $(BUILD_DIR)/dmg/Nudge.app
	ln -s /Applications $(BUILD_DIR)/dmg/Applications
	hdiutil create -volname Nudge -srcfolder $(BUILD_DIR)/dmg -fs HFS+ -format UDZO -ov $(DMG)
	codesign --force $(TIMESTAMP) --sign "$(SIGN_AS)" $(DMG)
	$(NOTARY) $(DMG)
	xcrun stapler staple $(DMG)
	spctl --assess --type execute --verbose $(BUILD_APP)
	spctl --assess --type open --context context:primary-signature --verbose $(DMG)
	cd $(BUILD_DIR) && shasum -a 256 $(notdir $(DMG)) > SHA256SUMS

icon:
	swift scripts/make-icon.swift

logs:
	log stream --predicate 'subsystem == "$(BUNDLE_ID)"' --level debug

clean:
	rm -rf $(BUILD_DIR)

VERSION   ?= 0.1.0
LABEL     := com.sagenkoder.nudge
BUILD_APP := .build/Nudge.app
APP_DIR   ?= $(HOME)/Applications
APP       := $(APP_DIR)/Nudge.app
AGENT     := $(HOME)/Library/LaunchAgents/$(LABEL).plist
DOMAIN    := gui/$(shell id -u)

# Sign with a stable identity so the Accessibility permission survives rebuilds.
# Falls back to ad-hoc signing ("-"), which makes macOS ask again after every build.
IDENTITY  ?= $(shell security find-identity -v -p codesigning 2>/dev/null | grep -m1 -o '"Apple Development[^"]*"' | tr -d '"' || true)
SIGN_AS   := $(if $(IDENTITY),$(IDENTITY),-)

.PHONY: all build test app install uninstall restart logs clean

all: app

build:
	swift build -c release

test:
	swift test

app: build
	rm -rf $(BUILD_APP)
	mkdir -p $(BUILD_APP)/Contents/MacOS
	cp "$$(swift build -c release --show-bin-path)/Nudge" $(BUILD_APP)/Contents/MacOS/Nudge
	sed 's/__VERSION__/$(VERSION)/g' Support/Info.plist > $(BUILD_APP)/Contents/Info.plist
	codesign --force --options runtime --timestamp=none --sign "$(SIGN_AS)" $(BUILD_APP)
	@echo "Signed with: $(SIGN_AS)"

install: app
	-launchctl bootout $(DOMAIN)/$(LABEL) 2>/dev/null
	mkdir -p $(APP_DIR) $(dir $(AGENT))
	rm -rf $(APP)
	cp -R $(BUILD_APP) $(APP)
	sed 's|__APP__|$(APP)|g' Support/$(LABEL).plist > $(AGENT)
	launchctl bootstrap $(DOMAIN) $(AGENT)
	@echo "Installed $(APP) and started it. It will start at every login."

uninstall:
	-launchctl bootout $(DOMAIN)/$(LABEL) 2>/dev/null
	rm -f $(AGENT)
	rm -rf $(APP)
	@echo "Removed. You can also remove Nudge from System Settings → Privacy & Security → Accessibility."

restart:
	launchctl kickstart -k $(DOMAIN)/$(LABEL)

logs:
	log stream --predicate 'subsystem == "$(LABEL)"' --level debug

clean:
	rm -rf .build

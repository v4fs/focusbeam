# VERSION is normally derived from the latest git tag; package managers
# building from a tarball (no .git) must pass it in: make app VERSION=x.y.z
VERSION ?= $(shell (git describe --tags --abbrev=0 2>/dev/null || echo v0.0.0) | sed 's/^v//')
APP = Focusbeam.app
BINARY = .build/release/focusbeam

.PHONY: build app clean

build:
	swift build -c release --disable-sandbox

app: build
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	sed 's/__VERSION__/$(VERSION)/g' Resources/Info.plist > $(APP)/Contents/Info.plist
	cp Resources/Focusbeam.icns $(APP)/Contents/Resources/
	cp $(BINARY) $(APP)/Contents/MacOS/focusbeam
	codesign --force --sign - $(APP)

clean:
	rm -rf .build $(APP)

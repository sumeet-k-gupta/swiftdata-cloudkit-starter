PROJECT  = Checklists.xcodeproj
SCHEME   = Checklists
DEST    ?= platform=iOS Simulator,name=iPhone 18 Pro

.PHONY: generate build test clean

generate:
	xcodegen generate

build: generate
	xcodebuild build -project $(PROJECT) -scheme $(SCHEME) -destination '$(DEST)' CODE_SIGNING_ALLOWED=NO

test: generate
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -destination '$(DEST)' CODE_SIGNING_ALLOWED=NO

clean:
	rm -rf $(PROJECT) DerivedData build

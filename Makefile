DERIVED_DATA = DerivedData
APP_PATH = $(DERIVED_DATA)/Build/Products/Release/Switcher.app

.PHONY: build package clean

build:
	xcodegen generate
	xcodebuild -project Switcher.xcodeproj \
		-scheme Switcher \
		-configuration Release \
		-derivedDataPath $(DERIVED_DATA) \
		CODE_SIGN_IDENTITY="-" \
		CODE_SIGNING_ALLOWED=YES

package: build
	codesign --force --deep --sign - "$(APP_PATH)"
	ditto -c -k --keepParent "$(APP_PATH)" Switcher.zip
	@echo "Created Switcher.zip"

clean:
	rm -rf $(DERIVED_DATA) Switcher.xcodeproj Switcher.zip

ARCHS := arm64
TARGET := iphone:clang:16.5:14.0
INSTALL_TARGET_PROCESSES := LeonMenu

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME := LeonMenu

LeonMenu_USE_MODULES := 0
LeonMenu_FILES += $(wildcard sources/*.mm sources/*.m)
LeonMenu_FILES += $(wildcard sources/KIF/*.m)

LeonMenu_CFLAGS += -fobjc-arc
LeonMenu_CFLAGS += -Iheaders -Isources -Isources/KIF
LeonMenu_CFLAGS += -include supports/prefix.pch
LeonMenu_CFLAGS += -Wno-deprecated-declarations -Wno-unused-function -Wno-unused-variable

LeonMenu_LDFLAGS += -Flibraries
LeonMenu_FRAMEWORKS += CoreGraphics CoreServices QuartzCore IOKit UIKit
LeonMenu_PRIVATE_FRAMEWORKS += BackBoardServices GraphicsServices SpringBoardServices
LeonMenu_CODESIGN_FLAGS += -Ssupports/entitlements.plist

include $(THEOS_MAKE_PATH)/application.mk

after-package::
	$(ECHO_NOTHING)rm -rf $(THEOS_STAGING_DIR)/Payload && mkdir -p packages $(THEOS_STAGING_DIR)/Payload$(ECHO_END)
	$(ECHO_NOTHING)cp -rp $(THEOS_STAGING_DIR)$(THEOS_PACKAGE_INSTALL_PREFIX)/Applications/LeonMenu.app $(THEOS_STAGING_DIR)/Payload$(ECHO_END)
	$(ECHO_NOTHING)ldid -Ssupports/entitlements.plist $(THEOS_STAGING_DIR)/Payload/LeonMenu.app/LeonMenu$(ECHO_END)
	$(ECHO_NOTHING)chmod 0644 $(THEOS_STAGING_DIR)/Payload/LeonMenu.app/Info.plist$(ECHO_END)
	$(ECHO_NOTHING)cd $(THEOS_STAGING_DIR); rm -f LeonMenu.tipa; zip -qr LeonMenu.tipa Payload; cd - >/dev/null$(ECHO_END)
	$(ECHO_NOTHING)mv -f $(THEOS_STAGING_DIR)/LeonMenu.tipa packages/LeonMenu.tipa$(ECHO_END)

ARCHS = arm64

include $(THEOS)/makefiles/common.mk

# Dynamic library loaded into SpringBoard by mobilesubstrate
TWEAK_NAME = BJUtils
BJUtils_FILES = $(wildcard MainUtils/*.m) $(wildcard PlainListeners/*.m)
BJUtils_FRAMEWORKS = UIKit IOKit AVFoundation CoreLocation MobileCoreServices
BJUtils_PRIVATE_FRAMEWORKS = MediaRemote PhotoLibrary SpringBoardUI BluetoothManager
BJUtils_LIBRARIES = activator
BJUtils_CFLAGS = -fobjc-arc

# Bundle loaded into SpringBoard by FlipSwitch
BUNDLE_NAME = DropbearSwitch
DropbearSwitch_FILES = dropbearswitch/BJDropbearSwitch.m
DropbearSwitch_LIBRARIES = flipswitch
DropbearSwitch_CFLAGS = -fobjc-arc
DropbearSwitch_INSTALL_PATH = /Library/Switches

# Command line tool with 6755 0:0 permissions, allowing execution as root wheel
TOOL_NAME = toggledropbear
toggledropbear_FILES = dropbearswitch/toggledropbear.m
toggledropbear_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk
include $(THEOS_MAKE_PATH)/tool.mk

after-install::
	install.exec "killall -9 SpringBoard"

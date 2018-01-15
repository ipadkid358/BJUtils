ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BJUtils
BJUtils_FILES = BJServer.m BJWallpaper.m BJBatteryInfo.m BJSBAlertItem.m BJLocation.m BJPrayerInfo.m BJWeatherInfo.m BJBluetooth.m
BJUtils_FRAMEWORKS = UIKit IOKit AVFoundation CoreLocation MobileCoreServices
BJUtils_PRIVATE_FRAMEWORKS = MediaRemote PhotoLibrary SpringBoardUI BluetoothManager
BJUtils_LIBRARIES = activator flipswitch
BJUtils_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"

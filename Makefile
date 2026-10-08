TARGET := iphone:clang:16.5:15.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = YouTube

# Chi build cho Dopamine (rootless)
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = YouTubeX
YouTubeX_FILES = Tweak.x
YouTubeX_CFLAGS = -fobjc-arc
YouTubeX_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += youtubexprefs
include $(THEOS_MAKE_PATH)/aggregate.mk

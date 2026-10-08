TARGET := iphone:clang:16.5:15.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = YouTubeXPrefs

YouTubeXPrefs_FILES = YTXRootListController.m
YouTubeXPrefs_FRAMEWORKS = UIKit
YouTubeXPrefs_PRIVATE_FRAMEWORKS = Preferences
YouTubeXPrefs_INSTALL_PATH = /Library/PreferenceBundles
# Version shown in the footer card, read from ../control.
YouTubeXPrefs_CFLAGS = -fobjc-arc -DTWEAK_VERSION=\"$(shell sed -n 's/^Version: *//p' ../control | tr -d '\r')\"

include $(THEOS_MAKE_PATH)/bundle.mk

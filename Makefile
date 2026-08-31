ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = WeChat

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = D

D_FILES = D.xm fishhook.c
D_CFLAGS = -fobjc-arc
D_FRAMEWORKS = UIKit Foundation AVFoundation CoreMedia CoreVideo \
                   CoreImage CoreGraphics QuartzCore ImageIO AudioToolbox \
                   UniformTypeIdentifiers

include $(THEOS_MAKE_PATH)/tweak.mk

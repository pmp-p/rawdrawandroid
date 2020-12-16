#Copyright (c) 2019-2020 <>< Charles Lohr - Under the MIT/x11 or NewBSD License you choose.
# NO WARRANTY! NO GUARANTEE OF SUPPORT! USE AT YOUR OWN RISK

all : makecapk.apk

.PHONY : push run

# WARNING WARNING WARNING!  YOU ABSOLUTELY MUST OVERRIDE THE PROJECT NAME
# you should also override these parameters, get your own signatre file and make your own manifest.
APPNAME?=rawapi1921
LABEL?=$(APPNAME)
APKFILE ?= $(APPNAME).apk
PACKAGENAME?=org.beerware.$(APPNAME)
RAWDRAWANDROID?=.
RAWDRAWANDROIDSRCS=$(RAWDRAWANDROID)/android_native_app_glue.c
SRC?=test.c

#We've tested it with android version 22, 24, 28, 29 and 30.
#You can target something like Android 28, but if you set ANDROID_MIN to say 22, then
#Your app should (though not necessarily) support all the way back to Android 22.
ANDROID_MIN?=19
ANDROID_NEXT?=21
ANDROIDTARGET?=$(ANDROID_MIN)
#Default is to be strip down, but your app can override it.
CFLAGS?=-fpic -ffunction-sections -Os -fdata-sections -Wall -fvisibility=hidden
LDFLAGS?=-Wl,--gc-sections -s
ANDROID_FULLSCREEN?=y
UNAME := $(shell uname)





ANDROIDSRCS:= $(SRC) $(RAWDRAWANDROIDSRCS)

#if you have a custom Android Home location you can add it to this list.
#This makefile will select the first present folder.


ifeq ($(UNAME), Linux)
OS_NAME = linux-x86_64
endif
ifeq ($(UNAME), Darwin)
OS_NAME = darwin-x86_64
endif
ifeq ($(OS), Windows_NT)
OS_NAME = windows-x86_64
endif

# Search list for where to try to find the SDK
SDK_LOCATIONS += /data/cross/pydk/android-sdk
SDK_LOCATIONS += $(ANDROID_HOME)

#Just a little Makefile witchcraft to find the first SDK_LOCATION that exists
#Then find an ndk folder and build tools folder in there.
ANDROID_SDK_ROOT?=$(firstword $(foreach dir, $(SDK_LOCATIONS), $(basename $(dir) ) ) )

#NDK?=$(firstword $(ANDROID_NDK) $(ANDROID_NDK_HOME) $(wildcard $(ANDROID_SDK_ROOT)/ndk/*) $(wildcard $(ANDROID_SDK_ROOT)/ndk-bundle/*) )
NDK?=/data/cross/pydk/android-sdk/ndk-bundle.22
BUILD_TOOLS?=$(lastword $(wildcard $(ANDROID_SDK_ROOT)/build-tools/*) )
ADB?=$(ANDROID_SDK_ROOT)/platform-tools/adb


# fall back to default Android SDL installation location if valid NDK was not found
ifeq ($(NDK),)
	ANDROID_SDK_ROOT := ~/Android/Sdk
endif

# Verify if directories are detected
ifeq ($(ANDROID_SDK_ROOT),)
	$(error ANDROID_SDK_ROOT directory not found)
endif


ifeq ($(NDK),)
	$(error NDK directory not found)
endif

ifeq ($(BUILD_TOOLS),)
	$(error BUILD_TOOLS directory not found)
endif


testsdk :
	@echo "SDK:\t\t" $(ANDROID_SDK_ROOT)
	@echo "NDK:\t\t" $(NDK)
	@echo "Build Tools:\t" $(BUILD_TOOLS)

CFLAGS+=-Os -DANDROID -DAPPNAME=\"$(APPNAME)\"

ifeq (ANDROID_FULLSCREEN,y)
	CFLAGS +=-DANDROID_FULLSCREEN
endif

CFLAGS+= -I$(RAWDRAWANDROID)/rawdraw -I$(NDK)/sysroot/usr/include -I$(NDK)/sysroot/usr/include/android \
 -I$(NDK)/toolchains/llvm/prebuilt/linux-x86_64//sysroot/usr/include/android \
 -fPIC -I$(RAWDRAWANDROID) -DANDROID_MIN=$(ANDROID_MIN)
LDFLAGS += -lm -lGLESv3 -lEGL -landroid -llog
LDFLAGS += -shared -uANativeActivity_onCreate

CC_ARM64:=$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/bin/aarch64-linux-android$(ANDROID_NEXT)-clang
CC_ARM32:=$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/bin/armv7a-linux-androideabi$(ANDROID_MIN)-clang
CC_x86:=$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/bin/i686-linux-android$(ANDROID_NEXT)-clang
CC_x86_64=$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/bin/x86_64-linux-android$(ANDROID_NEXT)-clang
AAPT:=$(BUILD_TOOLS)/aapt

# Which binaries to build? Just comment/uncomment these lines:
TARGETS += makecapk/lib/arm64-v8a/lib$(APPNAME).so
TARGETS += makecapk/lib/armeabi-v7a/lib$(APPNAME).so
TARGETS += makecapk/lib/x86/lib$(APPNAME).so
TARGETS += makecapk/lib/x86_64/lib$(APPNAME).so

CFLAGS_ARM64:=-m64
CFLAGS_ARM32:=-mfloat-abi=softfp -m32
CFLAGS_x86:=-march=i686 -mtune=intel -mssse3 -mfpmath=sse -m32
CFLAGS_x86_64:=-march=x86-64 -msse4.2 -mpopcnt -m64 -mtune=intel
STOREPASS?=android
DNAME:="CN=example.com, OU=ID, O=Example, L=Doe, S=John, C=GB"
KEYSTOREFILE:=debug.keystore
ALIASNAME?=androiddebugkey

keystore : $(KEYSTOREFILE)

$(KEYSTOREFILE) :
	keytool -genkey -v -keystore $(KEYSTOREFILE) -alias $(ALIASNAME) -keyalg RSA -keysize 2048 -validity 10000 -storepass $(STOREPASS) -keypass $(STOREPASS) -dname $(DNAME)

folders:
	mkdir -p makecapk/lib/arm64-v8a
	mkdir -p makecapk/lib/armeabi-v7a
	mkdir -p makecapk/lib/x86
	mkdir -p makecapk/lib/x86_64

makecapk/lib/arm64-v8a/lib$(APPNAME).so : $(ANDROIDSRCS)
	mkdir -p makecapk/lib/arm64-v8a
	$(CC_ARM64) $(CFLAGS) $(CFLAGS_ARM64) -o $@ $^ -L$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/sysroot/usr/lib/aarch64-linux-android/$(ANDROID_NEXT) $(LDFLAGS)

makecapk/lib/armeabi-v7a/lib$(APPNAME).so : $(ANDROIDSRCS)
	mkdir -p makecapk/lib/armeabi-v7a
	$(CC_ARM32) $(CFLAGS) $(CFLAGS_ARM32) -o $@ $^ -L$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/sysroot/usr/lib/arm-linux-androideabi/$(ANDROID_MIN) $(LDFLAGS)

makecapk/lib/x86/lib$(APPNAME).so : $(ANDROIDSRCS)
	mkdir -p makecapk/lib/x86
	$(CC_x86) $(CFLAGS) $(CFLAGS_x86) -o $@ $^ -L$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/sysroot/usr/lib/i686-linux-android/$(ANDROID_NEXT) $(LDFLAGS)

makecapk/lib/x86_64/lib$(APPNAME).so : $(ANDROIDSRCS)
	mkdir -p makecapk/lib/x86_64
	$(CC_x86) $(CFLAGS) $(CFLAGS_x86_64) -o $@ $^ -L$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/sysroot/usr/lib/x86_64-linux-android/$(ANDROID_NEXT) $(LDFLAGS)

#We're really cutting corners.  You should probably use resource files.. Replace android:label="@string/app_name" and add a resource file.
#Then do this -S Sources/res on the aapt line.
#For icon support, add -S makecapk/res to the aapt line.  also,  android:icon="@mipmap/icon" to your application line in the manifest.
#If you want to strip out about 800 bytes of data you can remove the icon and strings.

#Notes for the past:  These lines used to work, but don't seem to anymore.  Switched to newer jarsigner.
#(zipalign -c -v 8 makecapk.apk)||true #This seems to not work well.
#jarsigner -verify -verbose -certs makecapk.apk



makecapk.apk : stop clean manifest $(TARGETS) $(EXTRA_ASSETS_TRIGGER) AndroidManifest.xml
	mkdir -p makecapk/assets
	cp -r Sources/assets/* makecapk/assets
	rm -rf temp.apk $(APKFILE)

	$(AAPT) package -f -F temp.apk \
 -I $(ANDROID_SDK_ROOT)/platforms/android-28/android.jar \
 -M AndroidManifest.xml -S Sources/res \
 -A makecapk/assets -v --target-sdk-version $(ANDROIDTARGET)

	unzip -o temp.apk -d makecapk
	rm -rf makecapk.apk

	# zip lib+assets
	cd makecapk && zip -D9r ../makecapk.apk . && zip -D0r ../makecapk.apk ./resources.arsc ./AndroidManifest.xml

	# sign the zip
	#cp -vf makecapk.apk debug.apk
	#$(JARSIGNER) -sigalg SHA1withRSA -digestalg SHA1 -verbose -keystore $(KEYSTOREFILE) -storepass $(STOREPASS) debug.apk $(ALIASNAME)
	#
	python3 -m pyjarsigner makecapk.apk debug.cert.pem debug.key.pem

	$(BUILD_TOOLS)/zipalign -v 4 debug.apk $(APKFILE)

	# sign the apk
	# Using the apksigner in this way is only required on Android 30+
	$(BUILD_TOOLS)/apksigner sign --key-pass pass:$(STOREPASS) --ks-pass pass:$(STOREPASS) --ks $(KEYSTOREFILE) $(APKFILE)

	# tidy
	rm -rf temp.apk makecapk.apk debug.apk
	@ls -l $(APKFILE)

manifest: AndroidManifest.xml

AndroidManifest.xml :
	rm -rf AndroidManifest.xml
	PACKAGENAME=$(PACKAGENAME) \
		ANDROIDVERSION=$(ANDROID_MIN) \
		ANDROIDTARGET=$(ANDROID_NEXT) \
		APPNAME=$(APPNAME) \
		LABEL=$(LABEL) envsubst '$$ANDROIDTARGET $$ANDROIDVERSION $$APPNAME $$PACKAGENAME $$LABEL' \
		< AndroidManifest.xml.template > AndroidManifest.xml

deps:
	pip3 install git+https://github.com/pmp-p/M2Crypto
	#pip3 install git+https://github.com/pycrypto/pycrypto
	pip3 install git+https://github.com/pmp-p/pyjarsigner

uninstall:
	($(ADB) uninstall $(PACKAGENAME))||true

push: makecapk.apk
	@echo "Installing" $(PACKAGENAME)
	$(ADB) install -r $(APKFILE)

run: push
	$(eval ACTIVITYNAME:=$(shell $(AAPT) dump badging $(APKFILE) | grep "launchable-activity" | cut -f 2 -d"'"))
	$(ADB) shell am start -n $(PACKAGENAME)/$(ACTIVITYNAME)

stop:
	$(ADB) shell am force-stop $(PACKAGENAME)

clean:
	rm -rf temp.apk makecapk.apk makecapk debug.apk AndroidManifest.xml $(APKFILE)


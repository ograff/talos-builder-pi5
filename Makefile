PKG_VERSION = v1.10.0
TALOS_VERSION = v1.10.2
SBCOVERLAY_VERSION = main

REGISTRY ?= ghcr.io
REGISTRY_USERNAME ?= ograff

TAG ?= $(shell git describe --tags --exact-match)

EXTENSIONS ?= --system-extension-image=ghcr.io/siderolabs/tailscale:1.82.5@sha256:84e12fb6e84f6f83a1711655f723fc60185c0adb38cb76d08416ea4a84e12cd9 --system-extension-image=ghcr.io/siderolabs/iscsi-tools:v0.2.0@sha256:f2d78a7f19d301f2bf88ec99d948ffc63778125ce3acb0146049b75ed7ecd18c --system-extension-image=ghcr.io/siderolabs/util-linux-tools:2.40.4@sha256:f305315aec4fe0a355fb933c919a25550c67785acb193ee2842784317b5fa66b

PKG_REPOSITORY = https://github.com/siderolabs/pkgs.git
TALOS_REPOSITORY = https://github.com/siderolabs/talos.git
SBCOVERLAY_REPOSITORY = https://github.com/talos-rpi5/sbc-raspberrypi5.git

CHECKOUTS_DIRECTORY := $(PWD)/checkouts
PATCHES_DIRECTORY := $(PWD)/patches

PKGS_TAG = $(shell cd $(CHECKOUTS_DIRECTORY)/pkgs && git describe --tag --always --dirty --match v[0-9]\*)
TALOS_TAG = $(shell cd $(CHECKOUTS_DIRECTORY)/talos && git describe --tag --always --dirty --match v[0-9]\*)
SBCOVERLAY_TAG = $(shell cd $(CHECKOUTS_DIRECTORY)/sbc-raspberrypi5 && git describe --tag --always --dirty)-$(PKGS_TAG)

#
# Help
#
.PHONY: help
help:
	@echo "checkouts : Clone repositories required for the build"
	@echo "patches   : Apply all patches"
	@echo "kernel    : Build kernel"
	@echo "overlay   : Build Raspberry Pi 5 overlay"
	@echo "installer : Build installer docker image and disk image"
	@echo "release   : Use only when building the final release, this will tag relevant images with the current Git tag."
	@echo "clean     : Clean up any remains"



#
# Checkouts
#
.PHONY: checkouts checkouts-clean
checkouts:
	git clone -c advice.detachedHead=false --branch "$(PKG_VERSION)" "$(PKG_REPOSITORY)" "$(CHECKOUTS_DIRECTORY)/pkgs"
	git clone -c advice.detachedHead=false --branch "$(TALOS_VERSION)" "$(TALOS_REPOSITORY)" "$(CHECKOUTS_DIRECTORY)/talos"
	git clone -c advice.detachedHead=false --branch "$(SBCOVERLAY_VERSION)" "$(SBCOVERLAY_REPOSITORY)" "$(CHECKOUTS_DIRECTORY)/sbc-raspberrypi5"

checkouts-clean:
	rm -rf "$(CHECKOUTS_DIRECTORY)/pkgs"
	rm -rf "$(CHECKOUTS_DIRECTORY)/talos"
	rm -rf "$(CHECKOUTS_DIRECTORY)/sbc-raspberrypi5"



#
# Patches
#
.PHONY: patches-pkgs patches-talos patches
patches-pkgs:
	cd "$(CHECKOUTS_DIRECTORY)/pkgs" && \
		git am "$(PATCHES_DIRECTORY)/siderolabs/pkgs/0001-Patched-for-Raspberry-Pi-5.patch"

patches-talos:
	cd "$(CHECKOUTS_DIRECTORY)/talos" && \
		git am "$(PATCHES_DIRECTORY)/siderolabs/talos/0001-Patched-for-Raspberry-Pi-5.patch"

patches: patches-pkgs patches-talos



#
# Kernel
#
.PHONY: kernel
kernel:
	cd "$(CHECKOUTS_DIRECTORY)/pkgs" && \
		$(MAKE) \
			REGISTRY=$(REGISTRY) USERNAME=$(REGISTRY_USERNAME) PUSH=true \
			PLATFORM=linux/arm64 \
			kernel



#
# Overlay
#
.PHONY: overlay
overlay:
	@echo SBCOVERLAY_TAG = $(SBCOVERLAY_TAG)
	cd "$(CHECKOUTS_DIRECTORY)/sbc-raspberrypi5" && \
		$(MAKE) \
			REGISTRY=$(REGISTRY) USERNAME=$(REGISTRY_USERNAME) IMAGE_TAG=$(SBCOVERLAY_TAG) PUSH=true \
			PKGS_PREFIX=$(REGISTRY)/$(REGISTRY_USERNAME) PKGS=$(PKGS_TAG) \
			INSTALLER_ARCH=arm64 PLATFORM=linux/arm64 \
			sbc-raspberrypi5



#
# Installer/Image
#
.PHONY: installer
installer:
	cd "$(CHECKOUTS_DIRECTORY)/talos" && \
		$(MAKE) \
			REGISTRY=$(REGISTRY) USERNAME=$(REGISTRY_USERNAME) PUSH=true \
			PKG_KERNEL=$(REGISTRY)/$(REGISTRY_USERNAME)/kernel:$(PKGS_TAG) \
			INSTALLER_ARCH=arm64 PLATFORM=linux/arm64 \
			IMAGER_ARGS="--overlay-name=rpi5 --overlay-image=$(REGISTRY)/$(REGISTRY_USERNAME)/sbc-raspberrypi5:$(SBCOVERLAY_TAG) $(EXTENSIONS)" \
			kernel initramfs imager installer-base installer && \
		docker \
			run --rm -t -v ./_out:/out -v /dev:/dev --privileged $(REGISTRY)/$(REGISTRY_USERNAME)/imager:$(TALOS_TAG) \
			metal --arch arm64 \
			--base-installer-image="$(REGISTRY)/$(REGISTRY_USERNAME)/installer:$(TALOS_TAG)" \
			--overlay-name="rpi5" \
			--overlay-image="$(REGISTRY)/$(REGISTRY_USERNAME)/sbc-raspberrypi5:$(SBCOVERLAY_TAG)" \
			$(EXTENSIONS)



#
# Release
#
.PHONY: release
release:
	docker pull $(REGISTRY)/$(REGISTRY_USERNAME)/installer:$(TALOS_TAG) && \
		docker tag $(REGISTRY)/$(REGISTRY_USERNAME)/installer:$(TALOS_TAG) $(REGISTRY)/$(REGISTRY_USERNAME)/installer:$(TAG) && \
		docker push $(REGISTRY)/$(REGISTRY_USERNAME)/installer:$(TAG)



#
# Clean
#
.PHONY: clean
clean: checkouts-clean

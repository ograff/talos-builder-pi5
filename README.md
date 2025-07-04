# Raspberry Pi 5 Talos Builder
This repository serves as the glue to build custom Talos images for the Raspberry Pi 5. It patches the Kernel and Talos build process to use the Linux Kernel source provided by [raspberrypi/linux](https://github.com/raspberrypi/linux). 

## Tested on
So far, this release has been verified on:

| ✅ Hardware                                                |
|------------------------------------------------------------|
| Raspberry Pi Compute Module 5 on Compute Module 5 IO Board |
| Raspberry Pi Compute Module 5 Lite on [DeskPi Super6C](https://wiki.deskpi.com/super6c/) |
| Raspberry Pi 5b with [RS-P11 for RS-P22 RPi5](https://wiki.52pi.com/index.php?title=EP-0234) |

## How to use?
The releases on this repository align with the corresponding Talos version. There is a raw disk image (initial setup) and an installer image (upgrades) provided. 

### Examples
Initial:
```
unzstd metal-arm64-rpi.raw.zst
dd if=metal-arm64-rpi.raw of=<disk> bs=4M status=progress
sync
```

Upgrade:
```
talosctl upgrade \
  --nodes <node IP> \
  --image ghcr.io/ograff/installer:<version>
```

## Building
If you'd like to make modifications, it is possible to create your own build. Bellow is an example of the standard build.

```
# Clones all dependencies and applies the necessary patches
make checkouts patches

# Builds the Linux Kernel (can take a while)
make REGISTRY=ghcr.io REGISTRY_USERNAME=<username> kernel

# Builds the overlay (U-Boot, dtoverlays ...)
make REGISTRY=ghcr.io REGISTRY_USERNAME=<username> overlay

# Final step to build the installer and disk image
make REGISTRY=ghcr.io REGISTRY_USERNAME=<username> installer
```

## License
See [LICENSE](LICENSE).

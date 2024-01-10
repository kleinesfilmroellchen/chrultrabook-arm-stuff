# Collection of things possibly useful for Arch Linux ARM on chromebooks

Check out the justfile for a bunch of scripts that will build a kernel and assemble a possibly-functional image. (Since drivers on my device are broken I can’t verify that it actually works.)

## Dependencies

Probably incomplete list of dependencies you need.

- coreboot-utils (AUR) for checking vboot-utils, you need to modify the prepare() according to [this comment](https://aur.archlinux.org/packages/coreboot-utils#comment-949575). Alternatively you can disable vboot-utils tests by using `makepkg -s --nocheck`.
- patched vboot-utils from [this repo](https://github.com/kleinesfilmroellchen/vboot-utils-aur)
- fdisk
- uboot-tools
- depthcharge-tools (AUR)
- other depthcharge-tools dependencies as needed
- dtc
- bc
- brotli (kernel compression for convenience)
- fuse2fs (creating rootfs)

Don’t install cgpt manually, vboot-utils will provide it for you.

# Other things here

- a patched submarine partition image and full disk image that work for me
- dumped and decompiled device tree for juniper-hvpu (not compatible with upstream Linux, just for reference purposes)

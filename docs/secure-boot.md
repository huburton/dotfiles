# Dual boot with Secure Boot on

Why: a game anticheat on the Windows side requires Secure Boot. Arch has to boot with it on as well,
without disabling it each time.

## The chain

```
UEFI firmware (Microsoft keys)
  └─ shimx64.efi          signed by Microsoft (shim-signed)
       └─ grubx64.efi     signed with my own key (sbctl), enrolled in shim as a MOK
            ├─ arch-linux.efi   unified kernel image (kernel + initramfs + cmdline), signed with the same key
            └─ reboot_to_windows.efi   tiny signed helper: sets BootNext to Windows and reboots
```

Windows and Arch share one EFI system partition; the firmware boot order is shim first, then Windows,
then GRUB without shim as a fallback.

## What made it work

- **One signing key, enrolled once.** `sbctl` creates the key; its public part is exported as DER and
  enrolled with `mokutil --import`, then confirmed in MokManager at the next boot.
- **GRUB built for shim.** Under shim's lock, GRUB refuses to load external modules, so every module it
  needs is embedded at build time (`grub-install … --modules="…"`), and the image needs an SBAT section
  (`--sbat /usr/share/grub/sbat.csv`): recent shim rejects images without one.
- **A unified kernel image instead of kernel + initramfs.** The initramfs is not signed by itself, and
  shim's lock refused it (black screen). Packing kernel, initramfs and command line into one signed
  UKI fixed that.
- **Re-sign after every change.** `grub-install` drops the signature; the sbctl pacman hook signs GRUB
  and the kernel again, and an mkinitcpio post hook signs the UKI on every rebuild. My update script
  (`system/sbin/maj-auto`) checks after a kernel update that the UKI really contains the new kernel and
  is signed, before the next boot.
- **Keep the UKI small.** The shared ESP is 512 MB; dropping an unneeded initramfs hook took the image from
  275 MB to 128 MB.

## Side effects worth knowing

- Turning Secure Boot on or off changes the TPM measurements, so Windows Hello asks for a new PIN once.
- Windows keeps the hardware clock in local time; Linux was told the same (`timedatectl set-local-rtc 1`).

Keys, partition IDs and boot entry numbers are left out on purpose.

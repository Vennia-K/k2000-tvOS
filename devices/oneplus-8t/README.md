# Device: OnePlus 8T (kebab)

The starting point for the port. Nothing here has run on the phone yet: this directory says what has
to be filled in and where each number has to come from, not that any of it is right.

| What | Where |
|---|---|
| SoC | Qualcomm Snapdragon 865 (SM8250, `kona` in the device tree) |
| Models | KB2000 / KB2001 / KB2003 / KB2005. The T-Mobile KB2007 usually cannot unlock its bootloader; do not buy one for this |
| UEFI for the phone | `uefi/` — a port of Mu-Silicium; upstream already has `Platforms/OnePlus/kebabPkg`, so the package itself does not have to be written |
| Prebuilt UEFI images | not here yet. `prebuilt/` still has to receive `SILICIUM_UEFI.fd`, `BootShim.bin`, `device-tree.dtb`, `ramdisk` and `mkbootimg.py` |
| The phone's firmware | not in the repository: `pull-firmware.sh` pulls it over `adb` into `fw-*/` at the top |
| SoC addresses | `soc.args`, written by `pull-soc.sh` from the phone's own device tree |

## What differs from the POCO X5 Pro (redwood)

Everything the kernel, loader and user space need per phone is in `xnu/files/bsd/dev/hakios_*.c`,
`devices/<name>/prebuilt/` and the UEFI port. The table is what has to be re-derived for kebab.

| Piece | POCO X5 Pro | OnePlus 8T | Where it lands |
|---|---|---|---|
| SoC | SM7325 (yupik), 1+3+4 | SM8250 (kona), 1+3+4 | boot args, `hakios.mpss.c`, `hakios.ipa.c` |
| GPU | Adreno 642L, `a660_*` | Adreno 650, `a650_*` | `hakios.adreno.c`, `fw-gpu/` |
| Modem | integrated, IPA 4.11 | external SDX55 over PCIe/MHI | `hakios.mpss.c`, `hakios.ipa.c`, `soc.args` — the largest unknown |
| Touch | Goodix GT9916 | Synaptics TCM (read the model off the device tree) | `hakios.touch.c` |
| Display | Xiaomi panel | Samsung AMOLED (read the panel node) | `hakios.display.c`, UEFI `DisplayDxe` |
| Wi-Fi | WCN6750 + ath11k | a different FastConnect part (read `wcn*` under `/vendor/firmware_mnt/image`) | `wifi/`, `fw-wifi/`, `hakios.wifi.c` |
| Storage | UFS | UFS 3.1 | `hakios.ufs.c` (controller addresses) |
| Haptics | Awinic AW8697 | to be read off the device tree | `hakios.haptic.c`, `fw-haptic/` |
| Charger | 67 W | 65 W | UEFI `QcomChargerApp`, `hakios.charger.c` |

Where the table says "read off", the number is not in this repository: pull the phone's device tree
(`pull-soc.sh`, or `adb pull /sys/firmware/fdt`) and read the node.

## What the phone reported (2026-10-28)

Read over `adb` from a KB2000:

```
ro.product.device   OnePlus8T          ro.product.board    kona
ro.product.model    KB2000             ro.soc.model        SM8250
ro.build.fingerprint  OPPO/KB2000/OnePlus8T:17/CP2A.260605.016/B.1645cfc_fc7850_fb6677:user/release-keys
ro.boot.flash.locked 1                ro.boot.verifiedbootstate  green
ro.debuggable       0
```

Two gates, both still shut:

- `ro.boot.flash.locked 1`: the bootloader is locked, so `fastboot boot` — the only way this system
  starts, everything lives in RAM — cannot run at all. Unlocking is step 1 below, not a detail.
- `ro.debuggable 0` on a user build: `adb pull /sys/firmware/fdt` and `ls /vendor/firmware` both come
  back `Permission denied`, so `pull-soc.sh` and `pull-firmware.sh` need `su`, or the firmware has to
  come out of a factory/OTA image instead of the phone.

## To fill in, in order

1. Unlock the bootloader, enable `adb`, and confirm `fastboot boot` works with a stock `boot.img`.
   The phone stays unflashed throughout: `xl` uploads the loader and the kernel into RAM.
2. Make the SoC boot args:

   ```sh
   devices/oneplus-8t/pull-soc.sh        # -> devices/oneplus-8t/soc.args
   ```

   Read what it wrote. `soc_ipa_base`, `soc_ipcc`, `soc_aoss`, `soc_rsc` and `soc_apps_smmu` come out
   of the device tree; `soc_smem`, `soc_cmd_db`, `soc_mpss_mem` and `soc_imem` have to be added by
   hand from the reserved-memory nodes (see the POCO's README for the full list).
3. Pull the firmware, after correcting the paths in the script for this phone:

   ```sh
   DEVICE=oneplus-8t make firmware
   ```

4. Build the UEFI (`uefi/README.md`), then replace `prebuilt/` with the results.
5. `mkxnuimg.py` takes the device from `DEVICE` (default `poco-x5-pro`), so
   `DEVICE=oneplus-8t ./xl enter` packs this directory's `prebuilt/`. Until that `prebuilt/` has the
   five files it fails at the image step, which is the intended first failure.

## Milestones

Do not skip: each one names the layer that broke.

1. `xl enter` reaches the loader and `xl log` returns text (UEFI + BootShim + XNUP addresses).
2. `xl run` with `-v` prints kernel output on the panel (memory map, `bootcpu`, UART-less console).
3. SpringBoard reaches the lock screen. Only then GPU, Wi-Fi, audio, camera, modem.

## Sources

- `Platforms/OnePlus/kebabPkg` in
  [Mu-Silicium](https://github.com/Project-Silicium/Mu-Silicium/tree/main/Platforms/OnePlus/kebabPkg)
  (`Resources/Configs/kebab.toml`: `uefi_fd.base = 0x9FC00000`, size `0x300000`).
- Mainline Linux device trees for `kebab` (panel, touch, UFS, regulator and mailbox nodes).
- The POCO X5 Pro directory next door is the worked example for every file here.

# UEFI for kebab

A port of [Project Silicium / Mu-Silicium](https://github.com/Project-Silicium/Mu-Silicium) to the
OnePlus 8T. Upstream already carries the platform package
[`Platforms/OnePlus/kebabPkg`](https://github.com/Project-Silicium/Mu-Silicium/tree/main/Platforms/OnePlus/kebabPkg)
(`kebab.dsc` / `kebab.fdf` / `DeviceBuild.py`, and `Resources/Configs/kebab.toml` with
`uefi_fd.base = 0x9FC00000`, `size = 0x300000`) and `Resources/DTBs/kebab.dtb`, so the device
package is not written here. What is missing is what HakiOS adds to any Mu-Silicium tree:

1. `BootShim/BootShim.S` — copy the "XNUP" container (the kernel and RAM disk staged behind the UEFI
   image) to a free, fixed address before `ExitBootServices`. The POCO uses `0xF0000000`; on kebab
   that address has to be checked against the phone's memory map (`xl memmap`) before it is used.
2. `Silicon/Silicium/SiliciumPkg/Library/BootManagerLib` — start the XNU loader from that container
   instead of showing a menu. The POCO's `XnuLoader.c` / `XnuLoader.h` are the reference; they are
   device independent.

The device tree in `Resources/DTBs/kebab.dtb` comes from the phone's `vendor_boot` (or
`adb pull /sys/firmware/fdt`), not from upstream if the shipped one is stale. `Binaries/kebab` (the
phone's own UEFI drivers, extracted from `xbl.img` with
[UEFIReader](https://github.com/WOA-Project/UEFIReader)) is what Project Silicium ships for other
phones; see its `files/Binaries/<device>/README.md`.

## Build

Packages as in Mu-Silicium's `setup_env.sh` (Arch: `git base-devel lld nasm clang llvm
aarch64-linux-gnu-gcc python python-pip python-virtualenv`).

```sh
# from the top of this repository
git clone https://github.com/Project-Silicium/Mu-Silicium.git Mu-Silicium
git -C Mu-Silicium checkout <the kebab port's base commit>   # record it in uefi/BASE
git -C Mu-Silicium submodule update --init --recursive

# then put the two HakiOS changes above into the tree, or copy them back once made

python3 -m venv venv && venv/bin/pip install -r Mu-Silicium/pip-requirements.txt
cd Mu-Silicium
source ../venv/bin/activate
python3 build_uefi.py -d kebab -r RELEASE   # -> Build/kebabPkg/RELEASE_CLANGPDB/FV/SILICIUM_UEFI.fd
```

The `mu_nasm` dependency comes through NuGet and wants Mono; without Mono, point it at the system
nasm:

```sh
D=Mu_Basecore/BaseTools/Bin/mu_nasm_extdep
mkdir -p $D/Linux-x86-64
echo 'version: 20016.1.1' > $D/extdep_state.yaml
ln -s /usr/bin/nasm /usr/bin/ndisasm $D/Linux-x86-64/
```

## What lands in prebuilt/

After a build, `mkxnuimg.py` (called by `./xl enter`) takes the UEFI from `Mu-Silicium/`. For this
phone to be usable without a Mu-Silicium tree, `devices/oneplus-8t/prebuilt/` needs the same five
pieces the POCO has:

| File | From |
|---|---|
| `SILICIUM_UEFI.fd` | `Mu-Silicium/Build/kebabPkg/RELEASE_CLANGPDB/FV/` |
| `BootShim.bin` | rebuilt with the patched `BootShim` |
| `device-tree.dtb` | the phone's `vendor_boot`, or `/sys/firmware/fdt` |
| `ramdisk`, `mkbootimg.py` | `Mu-Silicium/Resources/` |

`tools/update-prebuilt.sh` is still POCO-only; extend it before relying on it.
`devices/poco-x5-pro/uefi/export.sh` is the model for saving a tree's changes back into a device
directory (`mu-silicium.patch` plus `files/`).

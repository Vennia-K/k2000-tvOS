#!/bin/bash
# Pull the OnePlus 8T's own firmware out of its Android into the fw-*/ directories at the top of the
# repository (never committed: it is the vendor's). The phone is on adb, in Android.
#
# The paths below are a starting point taken from other SM8250 phones. They are NOT verified on
# kebab: run the "confirm" line first and fix the names. Missing files are reported, not fatal.
set -e
cd "$(dirname "$0")/../.."
pull() { # DIR SOURCE...  (missing files are told, not fatal)
	local dir=$1; shift
	mkdir -p "$dir"
	for f in "$@"; do adb pull "$f" "$dir/" >/dev/null 2>&1 || echo "pull-firmware.sh: $f: not on the phone"; done
	echo "pull-firmware.sh: $dir: $(ls -1 "$dir" | wc -l | tr -d ' ') files"
}
adb get-state >/dev/null

# GPU, Adreno 650. confirm: adb shell 'ls /vendor/firmware | grep -i a650'
pull fw-gpu /vendor/firmware/a650_gmu.bin /vendor/firmware/a650_sqe.fw \
	/vendor/firmware/a650_zap.mdt $(for i in $(seq -w 0 20); do echo /vendor/firmware/a650_zap.b$i; done)

# Audio DSP, which also carries battery and charging. confirm: adb shell 'ls /vendor/firmware_mnt/image | grep adsp'
pull fw-audio /vendor/firmware_mnt/image/adsp.mdt $(for i in $(seq -w 2 36); do echo /vendor/firmware_mnt/image/adsp.b$i; done)

# Modem: the 8T's is an external SDX55, not the integrated one the POCO has.
# confirm: adb shell 'ls /vendor/firmware_mnt/image | grep modem'
pull fw-modem /vendor/firmware_mnt/image/modem.mdt $(for i in $(seq -w 0 28); do echo /vendor/firmware_mnt/image/modem.b$i; done)

# TODO, one line each once the names are read off the phone:
#   Wi-Fi:  adb shell 'ls /vendor/firmware_mnt/image | grep -i wcn'
#   haptic: adb shell 'ls /vendor/firmware | grep -i -e aw -e haptic'
#   camera: adb shell 'ls /vendor/lib64/camera | grep -i com.qti'
# The kernel drivers that will use these are named in README.md.
echo "pull-firmware.sh: done; Wi-Fi also wants fw-wifi/mac (the radio's address) and fw-wifi/network (the network's name and passphrase)"

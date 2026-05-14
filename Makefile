# ============================================================
# C64 GEOS target
# ============================================================
C64_OUT     = geoNeko.cvt
C64_DISK    = geos-neko.d64
C64_SAMPLES = /usr/local/share/cc65/samples/geos/samples-geos.d64
C64_ASM     = geoNeko.s
C64_GRC     = geoNekores.grc
C64_FRAMES  = frames/neko_c64_frame_*.bin

C1541 = /Applications/vice-arm64-gtk3-3.8/bin/c1541
X64SC = /Applications/vice-arm64-gtk3-3.8/bin/x64sc

# ============================================================
# Apple II GEOS target
# ============================================================
A2_OUT      = geoNeko-apple.cvt
A2_ASM      = geoNeko-apple.s
A2_GRC      = geoNekores-apple.grc

# ============================================================
# Common
# ============================================================
AS       = cl65

all: c64 apple

# ============================================================
# C64 targets
# ============================================================
c64: $(C64_OUT)

$(C64_OUT): $(C64_ASM) $(C64_GRC) $(C64_FRAMES)
	$(AS) -t geos-cbm -o $(C64_OUT) $(C64_ASM) $(C64_GRC)

c64-disk: $(C64_OUT)
	cp $(C64_SAMPLES) $(C64_DISK)
	$(C1541) -attach $(C64_DISK) -geoswrite $(C64_OUT) 2>&1 | grep -v "^/Users/" || true
	$(C1541) -attach $(C64_DISK) -list 2>&1 | grep -i neko

c64-run: c64-disk
	$(X64SC) -autostart $(C64_DISK)

# ============================================================
# Apple II targets
# ============================================================
A2_DISK     = geo-neko-apple.po
ACX         = /usr/local/bin/acx

apple: $(A2_OUT)

$(A2_OUT): $(A2_ASM) $(A2_GRC) $(C64_FRAMES)
	$(AS) -t geos-apple -o $(A2_OUT) $(A2_ASM) $(A2_GRC)

apple-disk: $(A2_OUT) $(A2_DISK)

$(A2_DISK): $(A2_OUT)
	rm -f $(A2_DISK)
	$(ACX) -pro140 $(A2_DISK) "geoNeko"
	$(ACX) -geos $(A2_DISK) < $(A2_OUT)
	$(ACX) -l $(A2_DISK)

apple-run: apple-disk
	@echo "Boot GEOS 2.0 for Apple II in your emulator, then open drive 2 with $(A2_DISK)"

# ============================================================
# Clean
# ============================================================
clean:
	rm -f $(C64_OUT) $(A2_OUT) *.o *.map 2>/dev/null; true

.PHONY: all c64 c64-disk c64-run apple apple-disk apple-run clean

TARGET   = geos-cbm
OUT      = geoNeko.cvt
DISK     = geos-neko.d64
SAMPLES  = /usr/local/share/cc65/samples/geos/samples-geos.d64
ASM_SRC  = geoNeko.s
GRC_SRC  = geoNekores.grc
FRAMES   = frames/neko_c64_frame_*.bin

AS       = cl65
ASFLAGS  = -t $(TARGET) -o $(OUT)
C1541    = /Applications/vice-arm64-gtk3-3.8/bin/c1541
X64SC    = /Applications/vice-arm64-gtk3-3.8/bin/x64sc

all: $(OUT)

$(OUT): $(ASM_SRC) $(GRC_SRC) $(FRAMES)
	$(AS) $(ASFLAGS) $(ASM_SRC) $(GRC_SRC)

disk: $(OUT)
	cp $(SAMPLES) $(DISK)
	$(C1541) -attach $(DISK) -geoswrite $(OUT) 2>&1 | grep -v "^/Users/" || true
	$(C1541) -attach $(DISK) -list 2>&1 | grep -i neko

run: disk
	$(X64SC) -autostart $(DISK)

clean:
	rm -f $(OUT) *.o *.map 2>/dev/null; true

.PHONY: all disk run clean

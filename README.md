# geoNeko

Animated cat that chases the mouse pointer, for Commodore 64 GEOS 2.0.

Based on [a2d neko.s](https://github.com/a2stuff/a2d/blob/main/src/desk_acc/neko.s) by a2stuff.

Dedicated to Masha.

## Build

Requires [cc65](https://cc65.github.io/).

```
make
```

## Run

Requires a GEOS 2.0 system disk and VICE emulator (or real C64).

```
make disk    # write geoNeko to GEOS disk image
make run     # launch in VICE x64sc
```

Or manually:

```
cl65 -t geos-cbm -o geoNeko.cvt geoNeko.s geoNekores.grc
c1541 -attach geos.d64 -geoswrite geoNeko.cvt
```

Then run geoNeko from the GEOS desktop. Press STOP to quit.

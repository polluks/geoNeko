# geoNeko

Animated cat that chases the mouse pointer, for GEOS on Commodore 64 and Apple II.

Based on [a2d neko.s](https://github.com/a2stuff/a2d/blob/main/src/desk_acc/neko.s) by a2stuff.
Cat animation artwork originally by Naoshi Watanabe and Kenji Gotoh.

Dedicated to Masha.

## License

Copyright (C) 2026 a2stuff and contributors.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.

## Build

Requires [cc65](https://cc65.github.io/).

```
make          # build both C64 and Apple II targets
make c64      # build C64 target only
make apple    # build Apple II target only
```

## Run

### C64

Requires a GEOS 2.0 system disk and VICE emulator (or real C64).

```
make c64-disk    # write geoNeko to GEOS disk image
make c64-run     # launch in VICE x64sc
```

Or manually:

```
cl65 -t geos-cbm -o geoNeko.cvt geoNeko.s geoNekores.grc
c1541 -attach geos.d64 -geoswrite geoNeko.cvt
```

Then run geoNeko from the GEOS desktop. Press STOP to quit.

### Apple II

Requires a GEOS 2.0 for Apple II system disk.

```
make apple-disk    # create ProDOS disk image with geoNeko
```

Or manually:

```
cl65 -t geos-apple -o geoNeko-apple.cvt geoNeko-apple.s geoNekores.grc
```

Then run geoNeko from the GEOS desktop. Press ESC to quit.

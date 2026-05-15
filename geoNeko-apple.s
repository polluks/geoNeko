;;; geoNeko-apple.s - GEOS Apple II desk accessory
;;; Animated cat that chases the mouse pointer
;;; Based on a2d neko.s by a2stuff
;;; Copyright (C) 2026 a2stuff and contributors
;;;
;;; This program is free software: you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation, either version 3 of the License, or
;;; (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program.  If not, see <https://www.gnu.org/licenses/>.
;;;
;;; Build: cl65 -t geos-apple -o geoNeko-apple.cvt geoNeko-apple.s geoNekores.grc

;;; ============================================================
;;; GEOS Apple II zero-page system registers (R_BASE = $00)
;;; ============================================================
r0L     = $00
r0H     = $01
r1L     = $02
r1H     = $03
r2L     = $04
r2H     = $05
r3L     = $06
r3H     = $07
r4L     = $08
r4H     = $09
r5L     = $0A
r5H     = $0B
r6L     = $0C
r6H     = $0D
r7L     = $0E
r7H     = $0F
r8L     = $10
r8H     = $11
r9L     = $12
r9H     = $13
r10L    = $14
r10H    = $15

;;; ============================================================
;;; GEOS Apple II system variables
;;; ============================================================
appMain    = $0200
mouseXPos  = $0241          ; 2 bytes, X position
mouseYPos  = $0243          ; 1 byte, Y position
keyData    = $0245
random     = $024C

;;; ============================================================
;;; GEOS Apple II jump table (per Hitchhiker's Guide)
;;; ============================================================
SetPattern    = $FE36
Rectangle     = $FE39
BBMult        = $FECC
MainLoop      = $FE00
GetNextChar   = $FE75
EnterDeskTop  = $FF59
MouseOff      = $FE96
MouseUp       = $FE99
GetRandom     = $FEE4
GetScreenLine = $FF62
PutScreenLine = $FF65

;;; ============================================================
;;; Application constants
;;; ============================================================
CAT_W      = 32
CAT_H      = 32
CAT_BW     = 4                ; bytes per row
MOVE_STEP  = 8
THRESHOLD  = 8
ANIM_DELAY = 3
QUIT_KEY   = $1B             ; Apple II Escape key
SCR_LW     = 70              ; screen line width (bytes)
SCR_H      = 192

;;; State IDs
ST_REST    = 0
ST_CHASE   = 1
ST_SCRATCH = 2
ST_ITCH    = 3
ST_LICK    = 4
ST_YAWN    = 5
ST_SLEEP   = 6

;;; Frame IDs (32 frames total)
FR_UP1    = 0
FR_UP2    = 1
FR_UPR1   = 2
FR_UPR2   = 3
FR_R1     = 4
FR_R2     = 5
FR_DR1    = 6
FR_DR2    = 7
FR_D1     = 8
FR_D2     = 9
FR_DL1    = 10
FR_DL2    = 11
FR_L1     = 12
FR_L2     = 13
FR_UL1    = 14
FR_UL2    = 15
FR_SCRU1  = 16
FR_SCRU2  = 17
FR_SCRR1  = 18
FR_SCRR2  = 19
FR_SCRD1  = 20
FR_SCRD2  = 21
FR_SCRL1  = 22
FR_SCRL2  = 23
FR_SIT    = 24
FR_YAWN   = 25
FR_ITCH1  = 26
FR_ITCH2  = 27
FR_SLP1   = 28
FR_SLP2   = 29
FR_LICK   = 30
FR_SURP   = 31

FRAME_SIZE = 128             ; CAT_H * CAT_BW

;;; ============================================================
;;; BSS - uninitialized variables
;;; ============================================================
.segment "BSS"
nekoX:      .res 2           ; 16-bit X position (0-559)
nekoY:      .res 1           ; 8-bit Y position (0-191)
oldX:       .res 2
oldY:       .res 1
curFrame:   .res 1
oldFrame:   .res 1
tick:       .res 1
skip:       .res 2
state:      .res 1
movedFlag:  .res 1
savedAppM:  .res 2           ; saved appMain vector
lineBuf:    .res 70          ; screen line buffer for GetScreenLine/PutScreenLine
tmpByte:    .res 1           ; temporary byte for overlay

;;; ============================================================
;;; STARTUP - entry point, called by GEOS on load
;;; ============================================================
.segment "STARTUP"

.proc start
        ; Save appMain vector
        lda     appMain
        sta     savedAppM
        lda     appMain+1
        sta     savedAppM+1

        ; Hook appMain to our tick handler
        lda     #<animTick
        sta     appMain
        lda     #>animTick
        sta     appMain+1

        ; Initialize state
        lda     #0
        sta     state
        sta     curFrame
        sta     tick
        sta     movedFlag
        sta     skip
        sta     skip+1

        ; Start near center, below menu bar
        lda     #240
        sta     nekoX
        lda     #0
        sta     nekoX+1
        lda     #80
        sta     nekoY

        ; Enter GEOS MainLoop
        jsr     MainLoop
        ; MainLoop does not return (EnterDeskTop is called from animTick)
.endproc

;;; ============================================================
;;; CODE - main program logic
;;; ============================================================
.segment "CODE"

;;; ============================================================
;;; animTick - called each MainLoop iteration via appMain
;;; ============================================================
.proc animTick
        ; Throttle - skip frames if skip counter > 0
        lda     skip
        ora     skip+1
        bne     decSkip
        jmp     doTick
decSkip:
        dec     skip
        bne     :+
        dec     skip+1
:       rts

doTick:
        ; Reset skip counter
        lda     #ANIM_DELAY
        sta     skip
        lda     #0
        sta     skip+1

        ; Save current position as old
        lda     nekoX
        sta     oldX
        lda     nekoX+1
        sta     oldX+1
        lda     nekoY
        sta     oldY
        lda     curFrame
        sta     oldFrame

        ; Check for quit key
        jsr     GetNextChar
        cmp     #QUIT_KEY
        beq     quit

        inc     tick

        ; Compute absolute delta from cat to mouse
        sec
        lda     mouseXPos
        sbc     nekoX
        sta     r0L
        lda     mouseXPos+1
        sbc     nekoX+1
        sta     r0H
        bpl     checkX
        ; Negative delta X - negate
        lda     #0
        sec
        sbc     r0L
        sta     r0L
        lda     #0
        sbc     r0H
        sta     r0H
checkX:
        lda     r0L
        cmp     #THRESHOLD
        bcs     doChase
        lda     r0H
        bne     doChase

        ; X within threshold, check Y
        lda     mouseYPos
        sec
        sbc     nekoY
        bpl     checkY
        ; Negative delta Y - negate
        eor     #$FF
        clc
        adc     #1
checkY:
        cmp     #THRESHOLD
        bcs     doChase

        ;; Both X and Y within threshold - resting/sleeping
        jsr     stateRest
        jmp     drawUpdate

doChase:
        jsr     moveToMouse
        jsr     stateChase

drawUpdate:
        ; Erase cat at old position
        lda     movedFlag
        beq     :+
        jsr     eraseCat
:
        ; Draw cat at current position
        jsr     drawCat
        lda     #1
        sta     movedFlag

        rts

quit:
        ; Erase the cat before leaving
        lda     #1
        jsr     SetPattern
        jsr     eraseCat

        ; Restore appMain
        lda     savedAppM
        sta     appMain
        lda     savedAppM+1
        sta     appMain+1

        ; Return to GEOS desktop
        jmp     EnterDeskTop
.endproc

;;; ============================================================
;;; moveToMouse - move cat one step toward mouse
;;; ============================================================
.proc moveToMouse
        ; Move X
        lda     nekoX
        cmp     mouseXPos
        lda     nekoX+1
        sbc     mouseXPos+1
        bcs     moveLeft

        ; Move right
        clc
        lda     nekoX
        adc     #MOVE_STEP
        sta     nekoX
        lda     nekoX+1
        adc     #0
        sta     nekoX+1
        jmp     moveY

moveLeft:
        sec
        lda     nekoX
        sbc     #MOVE_STEP
        sta     nekoX
        lda     nekoX+1
        sbc     #0
        sta     nekoX+1

moveY:
        lda     nekoY
        cmp     mouseYPos
        beq     done
        bcs     moveUp

        ; Move down
        clc
        adc     #MOVE_STEP
        sta     nekoY
        rts

moveUp:
        sec
        sbc     #MOVE_STEP
        sta     nekoY
done:
        rts
.endproc

;;; ============================================================
;;; stateRest - choose random rest behavior
;;; ============================================================
.proc stateRest
        lda     random
        and     #$3F              ; 0-63
        cmp     #10
        bcs     :+
        ; Itch
        lda     #ST_ITCH
        ldx     #FR_ITCH1
        jmp     setStateFrame
:
        cmp     #20
        bcs     :+
        ; Yawn
        lda     #ST_YAWN
        ldx     #FR_YAWN
        jmp     setStateFrame
:
        cmp     #30
        bcs     :+
        ; Lick
        lda     #ST_LICK
        ldx     #FR_LICK
        bne     setStateFrame
:
        cmp     #45
        bcs     :+
        ; Sleep
        lda     #ST_SLEEP
        ldx     #FR_SLP1
        bne     setStateFrame
:
        ; Just sit
        lda     #ST_REST
        ldx     #FR_SIT
        bne     setStateFrame
.endproc

;;; ============================================================
;;; stateChase - select running frame based on mouse direction
;;; ============================================================
.proc stateChase
        lda     #ST_CHASE
        sta     state

        ; Alternate between two frames of each pair
        lda     tick
        and     #1
        sta     r0L

        ; Determine direction
        lda     nekoX
        cmp     mouseXPos
        lda     nekoX+1
        sbc     mouseXPos+1
        bcs     faceLeft

        ; Facing right
        lda     nekoY
        cmp     mouseYPos
        bcs     faceUR
        ; Down-right
        lda     r0L
        clc
        adc     #FR_DR1
        tax
        jmp     setFrame

faceUR:
        lda     r0L
        clc
        adc     #FR_UPR1
        tax
        jmp     setFrame

faceLeft:
        lda     nekoY
        cmp     mouseYPos
        bcs     faceUL
        ; Down-left
        lda     r0L
        clc
        adc     #FR_DL1
        tax
        jmp     setFrame

faceUL:
        lda     r0L
        clc
        adc     #FR_UL1
        tax
        jmp     setFrame
.endproc

;;; ============================================================
;;; setFrame - set curFrame from X
;;; ============================================================
.proc setFrame
        stx     curFrame
        rts
.endproc

;;; ============================================================
;;; setStateFrame - set state and frame
;;; ============================================================
.proc setStateFrame
        sta     state
        stx     curFrame
        rts
.endproc

;;; ============================================================
;;; drawCat - overlay curFrame at (nekoX, nekoY)
;;; Uses GetScreenLine/PutScreenLine for DHGR screen access
;;; ============================================================
.proc drawCat
        ; Get frame data pointer into r7
        lda     curFrame
        asl     a
        tax
        lda     frameTable,x
        sta     r7L
        lda     frameTable+1,x
        sta     r7H

        ; Calculate byte offset in line: nekoX >> 3
        lda     nekoX
        lsr     a
        lsr     a
        lsr     a
        cmp     #SCR_LW - CAT_BW + 1
        bcc     :+
        rts                     ; skip if off right edge
:
        sta     r6L             ; save byte offset in r6L

        lda     #0
        sta     r0L             ; row counter

rowLoop:
        ; screen_y = nekoY + row
        clc
        lda     nekoY
        adc     r0L
        cmp     #SCR_H
        bcs     nextRow         ; skip if past screen bottom

        sta     r5L             ; r5L = y for GetScreenLine/PutScreenLine
        lda     #0
        sta     r5H

        ; Set buffer pointer for GetScreenLine
        lda     #<lineBuf
        sta     r4L
        lda     #>lineBuf
        sta     r4H

        ; Read current screen line
        jsr     GetScreenLine

        ; Overlay frame data onto line buffer
        ; r6L holds byte offset in line (nekoX >> 3)
        ; r7 points to current row in frame data

        ; Compute lineBuf + offset -> r6H/r6L (as pointer)
        clc
        lda     #<lineBuf
        adc     r6L
        sta     r6L
        lda     #>lineBuf
        adc     #0
        sta     r6H

        ; Transparent overlay: 4 bytes of frame onto line buffer
        ldy     #0
olp:
        lda     (r7L),y         ; frame byte
        eor     #$FF
        and     (r6L),y         ; ~frame & screen
        sta     tmpByte
        lda     (r7L),y         ; frame byte (reload)
        ora     tmpByte         ; frame | (~frame & screen)
        sta     (r6L),y         ; write back

        iny
        cpy     #CAT_BW
        bne     olp

        ; Reload byte offset for next row
        lda     nekoX
        lsr     a
        lsr     a
        lsr     a
        sta     r6L

        ; Write modified line back to screen
        lda     #<lineBuf
        sta     r4L
        lda     #>lineBuf
        sta     r4H
        ; r5 already has y value
        jsr     PutScreenLine

nextRow:
        ; Advance frame pointer to next row (+CAT_BW bytes)
        clc
        lda     r7L
        adc     #CAT_BW
        sta     r7L
        bcc     :+
        inc     r7H
:
        inc     r0L
        lda     r0L
        cmp     #CAT_H
        bne     rowLoop

        rts
.endproc

;;; ============================================================
;;; eraseCat - fill old cat area with white via Rectangle
;;; ============================================================
.proc eraseCat
        ; Set pattern to solid white (erase)
        lda     #1
        jsr     SetPattern

        ; Set up Rectangle parameters
        ; r1L = top (oldY), r1H = bottom (oldY + CAT_H - 1)
        ; r2 = left (oldX), r3 = right (oldX + CAT_W - 1)

        lda     oldY
        sta     r1L
        clc
        adc     #CAT_H-1
        sta     r1H

        lda     oldX
        sta     r2L
        lda     oldX+1
        sta     r2H

        clc
        lda     r2L
        adc     #CAT_W-1
        sta     r3L
        lda     r2H
        adc     #0
        sta     r3H

        jsr     Rectangle
        rts
.endproc

;;; ============================================================
;;; Frame address table
;;; ============================================================
.segment "RODATA"

frameTable:
        .addr   f01, f02, f03, f04, f05, f06, f07, f08
        .addr   f09, f10, f11, f12, f13, f14, f15, f16
        .addr   f17, f18, f19, f20, f21, f22, f23, f24
        .addr   f25, f26, f27, f28, f29, f30, f31, f32

;;; ============================================================
;;; Frame bitmaps (32x32 monochrome, 128 bytes each)
;;; Same C64 format: 4 bytes/row, 8 pixels/byte
;;; ============================================================
.segment "RODATA"

.macro incCF n
        .incbin .sprintf("frames/neko_c64_frame_%02d.bin", n)
.endmacro

f01: incCF 1
f02: incCF 2
f03: incCF 3
f04: incCF 4
f05: incCF 5
f06: incCF 6
f07: incCF 7
f08: incCF 8
f09: incCF 9
f10: incCF 10
f11: incCF 11
f12: incCF 12
f13: incCF 13
f14: incCF 14
f15: incCF 15
f16: incCF 16
f17: incCF 17
f18: incCF 18
f19: incCF 19
f20: incCF 20
f21: incCF 21
f22: incCF 22
f23: incCF 23
f24: incCF 24
f25: incCF 25
f26: incCF 26
f27: incCF 27
f28: incCF 28
f29: incCF 29
f30: incCF 30
f31: incCF 31
f32: incCF 32

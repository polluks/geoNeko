;;; geoNeko.s - GEOS C64 desk accessory
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
;;; Build: cl65 -t geos-cbm -o geoNeko.cvt geoNeko.s geoNekores.grc

;;; ============================================================
;;; GEOS C64 zero-page system variables
;;; ============================================================
r0L     = $02
r0H     = $03
r1L     = $04
r1H     = $05
r2L     = $06
r2H     = $07
r3L     = $08
r3H     = $09
r4L     = $0A
r4H     = $0B
r5L     = $0C
r5H     = $0D
r6L     = $0E
r6H     = $0F
r7L     = $10
r7H     = $11
r8L     = $12
r8H     = $13
r9L     = $14
r9H     = $15
r10L    = $16
r10H    = $17

mouseXL = $3A
mouseXH = $3B
mouseY  = $3C

dispBufferOn = $2F
mouseOn      = $30

SCREEN_BASE  = $A000

;;; ============================================================
;;; GEOS C64 ROM variables (page $84+)
;;; ============================================================
appMain   = $849B
keyData   = $8504
random    = $850A

;;; ============================================================
;;; GEOS C64 jump table (GEOS 2.0)
;;; ============================================================
Rect        = $C124
FrameRect   = $C127
InvertRect  = $C12A
SetPat      = $C139
BBMult      = $C160
BMult       = $C163
DMult       = $C166
MouseOff    = $C18D
MouseUp     = $C18A
GetRand     = $C187
MainLoop    = $C1C3
GetNxtChar  = $C2A7
EnterDesk   = $C22C

;;; ============================================================
;;; Application constants
;;; ============================================================
CAT_W      = 32
CAT_H      = 32
CAT_BW     = 4                ; bytes per row
MOVE_STEP  = 8
THRESHOLD  = 8
ANIM_DELAY = 3
QUIT_KEY   = 3                ; C64 STOP key
SCR_BPR    = 40               ; screen bytes per row

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

FRAME_SIZE = 128              ; CAT_H * CAT_BW

;;; ============================================================
;;; BSS - uninitialized variables
;;; ============================================================
.segment "BSS"
nekoX:      .res 2            ; 16-bit X position (0-319)
nekoY:      .res 1            ; 8-bit Y position (0-199)
oldX:       .res 2
oldY:       .res 1
curFrame:   .res 1
oldFrame:   .res 1
tick:       .res 1
skip:       .res 2
state:      .res 1
movedFlag:  .res 1
savedAppM:  .res 2            ; saved appMain vector

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

        ; Start near center-ish, below menu bar
        lda     #144
        sta     nekoX
        lda     #0
        sta     nekoX+1
        lda     #90
        sta     nekoY

        ; Enter GEOS MainLoop
        jsr     MainLoop
        ; MainLoop does not return (EnterDesktop is called from animTick)
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
        jsr     GetNxtChar
        cmp     #QUIT_KEY
        beq     quit

        inc     tick

        ; Compute absolute delta from cat to mouse
        sec
        lda     mouseXL
        sbc     nekoX
        sta     r0L
        lda     mouseXH
        sbc     nekoX+1
        sta     r0H
        bpl     checkX
        ; Negative delta X - negate
        lda     #0
        sec
        sbc     r0L
        sta     r0L
        lda     #0
        sbc     r0H       ; r0H is sign from above
        sta     r0H
checkX:
        lda     r0L
        cmp     #THRESHOLD
        bcs     doChase
        lda     r0H
        bne     doChase

        ; X within threshold, check Y
        lda     mouseY
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
        jsr     SetPat
        jsr     eraseCat

        ; Restore appMain
        lda     savedAppM
        sta     appMain
        lda     savedAppM+1
        sta     appMain+1

        ; Return to GEOS desktop
        jmp     EnterDesk
.endproc

;;; ============================================================
;;; moveToMouse - move cat one step toward mouse
;;; ============================================================
.proc moveToMouse
        ; Move X
        lda     nekoX
        cmp     mouseXL
        lda     nekoX+1
        sbc     mouseXH
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
        cmp     mouseY
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
        cmp     mouseXL
        lda     nekoX+1
        sbc     mouseXH
        bcs     faceLeft

        ; Facing right
        lda     nekoY
        cmp     mouseY
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
        cmp     mouseY
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
;;; drawCat - transparent overlay of curFrame at (nekoX, nekoY)
;;; Uses: r0-r3 (via BBMult), r4 (screen ptr), r5 (frame ptr)
;;; ============================================================
.proc drawCat
        ; Calculate: screen ptr = SCREEN_BASE + nekoY * 40 + (nekoX >> 3)
        lda     nekoY
        sta     r2L
        lda     #SCR_BPR
        jsr     BBMult          ; r0 = nekoY * 40

        clc
        lda     r0L
        adc     #<SCREEN_BASE
        sta     r4L
        lda     r0H
        adc     #>SCREEN_BASE
        sta     r4H

        lda     nekoX
        lsr     a
        lsr     a
        lsr     a
        clc
        adc     r4L
        sta     r4L
        bcc     :+
        inc     r4H
:
        lda     curFrame
        asl     a
        tax
        lda     frameTable,x
        sta     r5L
        lda     frameTable+1,x
        sta     r5H

        ldy     #0
rowLoop:
        tya
        pha

        ldy     #0
byteLoop:
        lda     (r5L),y
        eor     #$FF
        and     (r4L),y
        ora     (r5L),y
        sta     (r4L),y
        iny
        cpy     #CAT_BW
        bne     byteLoop

        clc
        lda     r4L
        adc     #SCR_BPR
        sta     r4L
        bcc     :+
        inc     r4H
:
        clc
        lda     r5L
        adc     #CAT_BW
        sta     r5L
        bcc     :+
        inc     r5H
:
        pla
        tay
        iny
        cpy     #CAT_H
        bne     rowLoop

        rts
.endproc

;;; ============================================================
;;; eraseCat - fill old cat area with white via Rectangle
;;; ============================================================
.proc eraseCat
        ; Set pattern to solid white (erase)
        lda     #1
        jsr     SetPat

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

        jsr     Rect
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

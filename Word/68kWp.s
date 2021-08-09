/* Basic word processor for 680000
 *
 * Copyright (C) 1991,2021 Dennis May
 * First Published 2021
 *
 * This file is part of 68000 Software Suite.
 *
 * 68000 Software Suite is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * 68000 Software Suite is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with 68000 Software Suite.  If not, see <https://www.gnu.org/licenses/>.
 */

.equ	err, 0
.equ	wrch, 1
.equ	rdch, 2
.equ	gen, 3
.equ	file, 4
.equ	asci, 6
.equ	newl, 7
.equ	msg, 8
.equ	escflg, 0x35
.equ	errvec, 0x80
.equ	page, 0xc0
.equ	top, 0xc4
.equ	himem, 0xc8
.equ	user, 0xcc
.equ	lmrg, 0xd0
.equ	llen, 0xd1
.equ	jsmd, 0xd2
.equ	lspc, 0xd3
.equ	prtc, 0xd4
.equ	lnpg, 0xd5
.equ	pgnum, 0xd6
.equ	stsc, 0xd8
.equ	scrn1, 0xdc
.equ	scrn2, 0xe0
.equ	csrrow, 0xe4
.equ	csrcol, 0xe5
.equ	fndstrlen, 0xe6
.equ	csflg, 0xe7
.equ	stln1, 0xe8
.equ	csrpos, 0xec
.equ	prtflg, 0xf0
.equ	lmrg2, 0xf1
.equ	llen2, 0xf2
.equ	jsmd2, 0xf3
.equ	pgmd, 0xf4
.equ	edmd, 0xf5
.equ	rnd, 0xf6
.equ	rndf, 0xf8
.equ	linebuf, 0x1200
.equ	fndstr, 0x1400
.equ	ibuf, 0x1300
.equ	scbf1, 0x1500
.equ	scbf2, 0x1a00

    .section .text
    .global START

START:
	bra entry
inkey:
	trap #rdch
	bcs.s escape
	rts
escape:
	trap #err
	dc.b 17
.ascii  "Escape"
	dc.b  0
.align 2
fw:
	trap #msg
	dc.b 28
	dc.b  60
	dc.b  0
	dc.b  79
	dc.b  0
	dc.b  0
.align 2
	rts
sw:
	trap #msg
	dc.b 28
	dc.b  0
	dc.b  8
	dc.b  79
	dc.b  1
	dc.b  0
.align 2
	rts
mw:
	trap #msg
	dc.b 28
	dc.b  0
	dc.b  0
	dc.b  59
	dc.b  0
	dc.b  10
	dc.b  0
.align 2
	rts
tw:
	trap #msg
	dc.b 28
	dc.b  0
	dc.b  24
	dc.b  79
	dc.b  9
	dc.b  0
.align 2
	rts
verify:
	bsr.s mw
	trap #msg
.ascii "ARE YOU SURE?"
	dc.b  0
.align 2
	bsr.s curon
	bsr.s inkey
	and.b #0xdf, d0
	move.b d0, -(a7)
	bsr.s curoff
	trap #newl
	bsr.s tw
	cmp.b #89, (a7)+
	rts
curon:
	move.w sr, -(a7)
	trap #msg
	dc.b 23
	dc.b  1
	dc.b  1
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  0
.align 2
	move.w (a7)+, ccr
	rts
curoff:
	move.w sr, -(a7)
	trap #msg
	dc.b 23
	dc.b  1
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  0
.align 2
	move.w (a7)+, ccr
	rts
screen:
	trap #msg
	dc.b 13
	dc.b  10
.ascii "CONTROL CODES\:"
.align 2
	dc.b 13, 10
.ascii "A=NEW PARA; B=BACK PARA; C=COUNT WORDS; D=BLOCK DELETE; E=BACK WORD; F=NEXT PARA"
.ascii "G=FIND STRING; H=FIND PREVIOUS; I=FIND NEXT; J=FILE PREVIEW; K=FILE PRINT"
	dc.b  13
	dc.b  10
.ascii "L=LOAD; RETURN=NEW LINE; N=NEXT WORD; O=PREVIEW MEM; P=PRINT MEM; R=OLD"
	dc.b  13
	dc.b  10
.ascii "S=SAVE; T=COPY BLOCK; U=UP SCREEN; V=DOWN SCREEN; W=SEARCH & REPLACE"
	dc.b  13
	dc.b  10
.ascii "X=INSERT/OVERWRITE; Y=AUTOINDENT ON/OFF"
	dc.b  13
	dc.b  10
.ascii "<=OSCLI; >=MERGE; -=SAVE BLOCK; ?=NEW"
	dc.b  31
	dc.b  0
	dc.b  8
	dc.b  0
.align 2
	moveq #79, d1
	moveq #0x2d, d0
screen1:
	trap #wrch
	dbra d1, screen1
	bsr.s flags
	bra tw
flags:
	bsr curoff
	bsr fw
	tst.b edmd
	bpl.s flags1
	trap #msg
	dc.b 17
	dc.b  0
	dc.b  17
	dc.b  129
.ascii  "OVERWRITE"
	dc.b  17
	dc.b  1
	dc.b  17
	dc.b  128
	dc.b  32
	dc.b  0
.align 2
	bra.s flags2
flags1:
	trap #msg
	dc.b 17
	dc.b  0
	dc.b  17
	dc.b  129
.ascii  "INSERT"
	dc.b  17
	dc.b  1
	dc.b  17
	dc.b  128
.ascii  "    "
	dc.b  0
.align 2
flags2:
	btst #6, edmd
	bne.s flags3
	trap #msg
.ascii "      "
	dc.b  0
.align 2
	rts
flags3:
	trap #msg
	dc.b 17
	dc.b  0
	dc.b  17
	dc.b  129
.ascii  "INDENT"
	dc.b  17
	dc.b  1
	dc.b  17
	dc.b  128
	dc.b  0
.align 2
	rts
entry:
	move.l 0, a0
	lea -512(a0), a7
	lea -4096(a0), a0
	move.l a0, himem
	move.l a7, user
	move.l page, a0
	move.b #255, (a0)+
	move.l a0, top
	clr.b edmd
	trap #msg
	dc.b 22
	dc.b  3
	dc.b  0
	dc.b  0
.align 2
	bsr screen
	lea errhnd-.-2(pc), a0
	move.l a0, errvec
	lea restart-.-2(pc), a0
	moveq #0x13, d0
	trap #gen
	move.l #0xc0e100, d0
	trap #gen
	move.l #0x010400, d0
	trap #gen
	move.l #0x02018b00, d0
	trap #gen
oldrst:
	move.l page, a6
	move.l a6, stsc
	clr.b fndstrlen
	bsr clrsc
char:
	clr.b prtflg
	bsr eprt
	moveq #31, d0
	trap #wrch
	move.b csrcol, d0
	trap #wrch
	move.b csrrow, d0
	trap #wrch
	bsr curon
	move.l a6, csrpos
	bsr inkey
	bsr curoff
	cmp.b #32, d0
	bcs ctrlkey
	cmp.b #127, d0
	beq.s dltkey
	bcs.s instch
	cmp.b #0x8b, d0
	bls.s csrkey
	sub.b #64, d0
	bsr chkmkr
instch:
	cmp.b #255, (a6)
	beq.s instch1
	tst.b edmd
	bpl.s instch1
	move.b d0, (a6)
	bra.s csrfwd
instch1:
	move.l a6, a0
	move.b d0, d2
	bsr insert
	move.b d2, (a0)
	bra.s csrfwd
dltkey:
	cmp.l page, a6
	bls.s char
	lea -1(a6), a0
	bsr delete
	bra.s csrback
dlt2:
	move.l top, a0
	subq.l #1, a0
	cmp.l a0, a6
	bcc.s char
	move.l a6, a0
	bsr delete
bchar0:
	bra char
csrkey:
	cmp.b #0x88, d0
	beq.s csrback
	cmp.b #0x89, d0
	beq.s csrfwd
	cmp.b #0x8a, d0
	beq.s csrdwn
	cmp.b #0x8b, d0
	beq.s csrup
	cmp.b #0x87, d0
	beq.s dlt2
bchar1:
	bra.s bchar0
csrback:
	cmp.l page, a6
	bls.s bchar1
	subq.l #1, a6
	bra.s bchar1
csrfwd:
	lea 1(a6), a0
	cmp.l top, a0
	beq.s bchar1
	move.l a0, a6
bchar2:
	bra.s bchar1
csrdwn:
	move.l a6, a0
	bsr.s movdwn
	move.l a0, a6
bchar3:
	bra.s bchar2
csrup:
	move.l a6, a0
	bsr.s movup
	move.l a0, a6
bchar4:
	bra.s bchar3
movdwn:
	moveq #79, d0
movdwn1:
	move.b (a0)+, d1
	cmp.b #255, d1
	beq.s movdwn2
	cmp.b #1, d1
	beq.s movdwn3
	cmp.b #13, d1
	beq.s movdwn3
	dbra d0, movdwn1
	bra.s movdwn3
movdwn2:
	subq.l #1, a0
movdwn3:
	rts
movup:
	moveq #79, d0
	cmp.l page, a0
	bls.s movup2
movup1:
	move.b -(a0), d1
	cmp.l page, a0
	bls.s movup2
	cmp.b #1, d1
	beq.s movup2
	cmp.b #13, d1
	beq.s movup2
	dbra d0, movup1
movup2:
	rts
.equ	instpara, instch
instnewl:
	btst #6, edmd
	beq instch
	tst.b csrrow
	beq instch
	move.l scrn2, a0
	moveq #0, d1
	move.b csrrow, d1
	mulu #80, d1
	add.w d1, a0
	moveq #0, d1
indent1:
	cmp.b #32, 0(a0, d1.w)
	bne.s indent2
	addq.w #1, d1
	cmp.b #80, d1
	bcs.s indent1
	bra instch
indent2:
	cmp.b csrcol, d1
	bcc.s instnewl2
	moveq #1, d0
	add.w d1, d0
	move.w d1, d2
	bsr chkmem
	move.l a6, a0
	lea 0(a0, d0.w), a1
	move.l top, d1
	sub.l a1, d1
	moveq #7, d0
	trap #gen
	move.b #13, (a6)+
	bra.s indent4
indent3:
	move.b #32, (a6)+
indent4:
	dbra d2, indent3
	bra char
instnewl2:
	moveq #13, d0
	bra instch
ctrlkey:
	bsr mw
	trap #msg
	dc.b 12
	dc.b  0
.align 2
	bsr tw
	move.b d0, -(a7)
	ext.w d0
	add.w d0, d0
	lea cjt-.-2(pc), a0
	add.w 0(a0, d0.w), a0
	move.b (a7)+, d0
	jmp (a0)
.equ	noop, char-cjt
cjt:
	dc.w noop, instpara-cjt, backpara-cjt, count-cjt, dltblk-cjt
	dc.w backword-cjt, nxtpara-cjt, find-cjt, findprev-cjt, findnxt-cjt
	dc.w fileprv-cjt, fileprt-cjt, load-cjt, instnewl-cjt, nxtwrd-cjt
	dc.w memprv-cjt, memprt-cjt
	dc.w noop, old-cjt, save-cjt, blkcpy-cjt, upscreen-cjt, nxtsc-cjt
	dc.w snr-cjt, insover-cjt, indtsw-cjt, noop, noop
	dc.w oscli-cjt, blksav-cjt, merge-cjt, entry-cjt
errhnd1:
	tst.b prtflg
	bpl.s errhnd0
	trap #msg
	dc.b 3
	dc.b  22
	dc.b  3
	dc.b  0
.align 2
	bsr screen
	tst.b d7
	bmi.s errhnd0a
	move.l csrpos, a6
	move.w d7, d0
	move.b #4, d0
	trap #file
	bra.s errhnd0
errhnd0a:
	cmp.l page, a6
	bls.s errhnd0b
	subq.l #1, a6
errhnd0b:
	move.l a6, a0
	bsr movup
	bsr movup
	move.l a0, stsc
errhnd0:
	rts
errhnd:
	bsr.s errhnd1
	bsr mw
	bsr curoff
	move.l 2(a7), a0
	move.b (a0)+, 0x3e
	moveq #6, d0
	trap #gen
	move.l 0, a7
	clr.l 0x38
	clr.b 0x35
	st 0x3f
	move.w #0, sr
	move.l user, a7
	bsr tw
bchar5:
	bra char
restart:
	and.w #0xdfff, sr
	move.l user, a7
restart1:
	trap #msg
	dc.b 13
	dc.b  10
.ascii  "Press any key to continue"
	dc.b  0
.align 2
	trap #rdch
	bsr errhnd1
	move.l csrpos, a6
bchar6:
	bra.s bchar5
insover:
	bchg #7, edmd
	bsr flags
	bsr tw
	bra.s bchar6
indtsw:
	bchg #6, edmd
	bsr flags
	bsr tw
	bra.s bchar6
clrsc:
	lea scbf1, a0
	move.l a0, scrn1
	lea scbf2, a1
	move.l a1, scrn2
	move.l #0x20202020, d0
	move.w #319, d1
clrsc1:
	move.l d0, (a0)+
	move.l d0, (a1)+
	dbra d1, clrsc1
	rts
outsc:
	move.l scrn1, a0
	move.l scrn2, a1
	move.w #1279, d0
outsc1:
	cmpm.b (a0)+, (a1)+
	dbne d0, outsc1
	beq.s outsc0
	lea -1(a0), a2
	move.l a2, d1
	sub.l scrn1, d1
	divu #80, d1
	move.l scrn1, a0
	add.w #1280, a0
	move.l scrn2, a1
	add.w #1280, a1
outsc2:
	move.b -(a0), d0
	cmp.b -(a1), d0
	beq.s outsc2
	moveq #15, d0
	bsr.s outch
	moveq #9, d0
	add.b d1, d0
	bsr.s outch
	swap d1
	move.b d1, d0
	bsr.s outch
outsc3:
	move.b (a2)+, d0
	bsr.s outch
	cmp.l a0, a2
	bls.s outsc3
	moveq #0, d0
	bsr.s outch
	move.l scrn1, a0
	move.l scrn2, a1
	move.l a0, scrn2
	move.l a1, scrn1
outsc0:
	rts
outch:
	tst.b 0xffff8024
	move.b d0, 0xffff8024
outch1:
	tst.b 0xffff8026
	bpl.s outch1
	rts
eprt:
	st csrrow
	move.l scrn1, a0
	move.l stsc, a1
	moveq #0, d0
	moveq #79, d1
	cmp.l page, a1
	beq.s eprt0
	cmp.b #1, -1(a1)
	bne.s eprt0
	subq.b #4, d1
	move.l #0x20202020, (a0)+
eprt0:
	moveq #-1, d3
	cmp.b #1, d0
	bne.s eprt1
	move.l a1, stln1
eprt1:
	cmp.l a6, a1
	bne.s eprt2
	move.b d0, csrrow
	move.b d1, csrcol
eprt2:
	move.b (a1)+, d2
	bmi.s eprt3
	cmp.b #1, d2
	beq.s eprt4
	cmp.b #13, d2
	beq.s eprt5
	cmp.b #32, d2
	bne.s eprt6
	move.w d1, d3
eprt6:
	move.b d2, (a0)+
	dbra d1, eprt1
	tst.b d3
	ble.s eprt7
	sub.w d3, a1
	cmp.b csrrow, d0
	bne.s eprt8
	cmp.b csrcol, d3
	bls.s eprt8
	st csrrow
eprt8:
	neg.w d3
	moveq #32, d2
eprt9:
	move.b d2, 0(a0, d3.w)
	addq.w #1, d3
	bmi.s eprt9
eprt7:
	moveq #79, d1
eprt7a:
	addq.b #1, d0
	cmp.b #16, d0
	bcs.s eprt0
	moveq #79, d1
	sub.b csrcol, d1
	move.b d1, csrcol
	move.l a1, a3
	bra.s eprt10
eprt5:
	moveq #32, d2
eprt5a:
	move.b d2, (a0)+
	dbra d1, eprt5a
	bra.s eprt7
eprt4:
	moveq #32, d2
	cmp.b #15, d0
	beq.s eprt5a
	addq.w #4, d1
eprt4a:
	move.b d2, (a0)+
	dbra d1, eprt4a
	moveq #75, d1
	bra.s eprt7a
eprt3:
	cmp.b #255, d2
	blt.s eprt3b
	moveq #32, d2
	move.l scrn1, d1
	add.l #1279, d1
	sub.l a0, d1
eprt3a:
	move.b d2, (a0)+
	dbra d1, eprt3a
	moveq #79, d1
	sub.b csrcol, d1
	move.b d1, csrcol
	move.l a1, a3
	bra.s eprt10
eprt3b:
	add.b #48, d2
	bra eprt6
eprt10:
	tst.b csrrow
	bpl outsc
	cmp.l a3, a6
	bcs.s eprt11
	move.l stln1, stsc
	bra eprt
eprt11:
	move.l stsc, a0
	bsr movup
	move.l a0, stsc
	bra eprt
delete:
	move.l a0, a1
	cmp.l stsc, a0
	bcc.s delete1
	subq.l #1, stsc
delete1:
	addq.l #1, a0
	move.l top, d1
	sub.l a0, d1
	moveq #7, d0
	trap #gen
	subq.l #1, top
	rts
chkmem:
	move.l d0, -(a7)
	add.l top, d0
	cmp.l himem, d0
	bhi.s noroom
	move.l d0, top
	move.l (a7)+, d0
	rts
noroom:
	trap #err
	dc.b 0
.ascii  "No room"
	dc.b  0
.align 2
insert:
	moveq #1, d0
	bsr.s chkmem
	lea 1(a0), a1
	move.l top, d1
	sub.l a1, d1
	moveq #7, d0
	trap #gen
	rts
old:
	move.l page, a0
	move.w #0x2a2a, (a0)+
	moveq #-1, d0
old1:
	cmp.b (a0)+, d0
	bne.s old1
	move.l a0, top
	bra oldrst
findmkr:
	move.l page, a0
findmkr1:
	move.b (a0)+, d1
	bpl.s findmkr1
	cmp.b d0, d1
	beq.s foundmkr
	addq.b #1, d1
	bne.s findmkr1
	moveq #1, d1
foundmkr:
	subq.l #1, a0
	rts
chkmkr:
	cmp.b #0x87, d0
	bcs.s notmkr
	cmp.b #0x89, d0
	bhi.s notmkr
	bsr.s findmkr
	bne.s notmkr
	cmp.l a6, a0
	bcc.s dltmkr
	subq.l #1, a6
dltmkr:
	move.b d0, -(a7)
	bsr delete
	move.b (a7)+, d0
notmkr:
	rts
nxtwrd:
	moveq #1, d1
	moveq #13, d2
	moveq #32, d3
nxtwrd1:
	move.b (a6)+, d0
	bmi.s nxtwrd2
	cmp.b d1, d0
	beq.s nxtwrd3
	cmp.b d2, d0
	beq.s nxtwrd3
	cmp.b d3, d0
	bne.s nxtwrd1
nxtwrd3:
	move.b (a6)+, d0
	cmp.b d1, d0
	beq.s nxtwrd3
	cmp.b d2, d0
	beq.s nxtwrd3
	cmp.b d3, d0
	beq.s nxtwrd3
	subq.l #1, a6
	bra char
nxtwrd2:
	addq.b #1, d0
	bne.s nxtwrd1
	subq.l #1, a6
bchar7:
	bra char
backword:
	moveq #32, d1
	moveq #13, d2
	moveq #1, d3
	addq.l #1, a6
bkwd1:
	move.b -(a6), d0
	cmp.l page, a6
	bls.s bchar7
	cmp.b d1, d0
	beq.s bkwd2
	cmp.b d2, d0
	beq.s bkwd2
	cmp.b d3, d0
	bne.s bkwd1
bkwd2:
	move.b -(a6), d0
	cmp.l page, a6
	bls.s bchar7
	cmp.b d1, d0
	beq.s bkwd2
	cmp.b d2, d0
	beq.s bkwd2
	cmp.b d3, d0
	beq.s bkwd2
bkwd3:
	move.b -(a6), d0
	cmp.l page, a6
	bls.s bchar7
	cmp.b d1, d0
	beq.s bkwd4
	cmp.b d2, d0
	beq.s bkwd4
	cmp.b d3, d0
	bne.s bkwd3
bkwd4:
	addq.l #1, a6
bchar8:
	bra.s bchar7
backpara:
	move.l page, a0
	moveq #1, d1
	moveq #13, d2
bkpara1:
	move.b -(a6), d0
	cmp.b d1, d0
	beq.s bkpara2
	cmp.b d2, d0
	beq.s bkpara2
	cmp.l a0, a6
	bcc.s bkpara1
	addq.l #1, a6
bkpara2:
	bra.s bchar8
nxtpara:
	moveq #1, d1
	moveq #13, d2
nxtpara1:
	move.b (a6)+, d0
	bmi.s nxtpara2
	cmp.b d1, d0
	beq.s nxtpara3
	cmp.b d2, d0
	bne.s nxtpara1
nxtpara3:
	bra char
nxtpara2:
	addq.b #1, d0
	bne.s nxtpara1
	subq.l #1, a6
	bra.s nxtpara3
upscreen:
	move.l stsc, a0
	moveq #11, d2
upsc1:
	bsr movup
	dbra d2, upsc1
	move.l a0, stsc
	move.l a0, a6
bchar9:
	bra.s bchar8
nxtsc:
	cmp.l top, a3
	bcc.s bchar9
	move.l a3, a6
	move.l a3, stsc
bchar10:
	bra.s bchar9
count:
	move.l page, a0
	moveq #32, d1
	moveq #1, d2
	moveq #13, d3
	moveq #0, d4
	bra.s count4
count1:
	move.b (a0)+, d0
	bmi.s count2a
	cmp.b d1, d0
	beq.s count3
	cmp.b d2, d0
	beq.s count3
	cmp.b d3, d0
	bne.s count1
count3:
	addq.l #1, d4
count4:
	move.b (a0)+, d0
	bmi.s count2
	cmp.b d1, d0
	beq.s count4
	cmp.b d2, d0
	beq.s count4
	cmp.b d3, d0
	beq.s count4
	bra.s count1
count2a:
	addq.l #1, d4
count2:
	addq.b #1, d0
	bne.s count1
	bsr mw
	move.l d4, d0
	bsr.s prtdec
	trap #msg
.ascii " word"
	dc.b  0
.align 2
	cmp.l #1, d0
	beq.s count5
	trap #msg
.ascii "s"
	dc.b  0
.align 2
count5:
	bsr tw
bchar11:
	bra.s bchar10
prtdec:
	move.l d0, -(a7)
	st -(a7)
prtdec1:
	bsr.s divby10
	add.b #48, d1
	move.b d1, -(a7)
	tst.l d0
	bne.s prtdec1
prtdec2:
	move.b (a7)+, d0
	bmi.s prtdec3
	trap #wrch
	bra.s prtdec2
prtdec3:
	move.l (a7)+, d0
	rts
divby10:
	move.w d0, d1
	clr.w d0
	swap d0
	divu #10, d0
	move.w d0, d2
	move.w d1, d0
	divu #10, d0
	swap d2
	move.w d0, d2
	swap d0
	move.w d0, d1
	move.l d2, d0
	rts
no7:
	trap #err
	dc.b 0
.ascii  "Marker 7 not present"
	dc.b  0
.align 2
no8:
	trap #err
	dc.b 0
.ascii  "Marker 8 not present"
	dc.b  0
.align 2
no9:
	trap #err
	dc.b 0
.ascii  "Marker 9 not present"
	dc.b  0
.align 2
order89:
	trap #err
	dc.b 0
.ascii  "Marker 8 must precede marker 9"
	dc.b  0
.align 2
chk89:
	moveq #-120, d0
	bsr findmkr
	bne.s no8
	move.l a0, a1
	moveq #-119, d0
	bsr findmkr
	bne.s no9
	cmp.l a0, a1
	bhi.s order89
	rts
cmdcan:
	trap #err
	dc.b 0
.ascii  "Command cancelled"
	dc.b  0
.align 2
dltblk:
	bsr.s chk89
	bsr verify
	bne.s cmdcan
	cmp.l a6, a1
	bcc.s dltblk1
	cmp.l a6, a0
	bhi.s dltblk2
	lea 1(a6, a1.l), a6
	sub.l a0, a6
	cmp.l stsc, a1
	bcc.s dltblk1
	move.l a1, stsc
	bra.s dltblk1
dltblk2:
	lea 1(a1), a6
	cmp.l stsc, a1
	bcc.s dltblk1
	move.l a1, stsc
dltblk1:
	addq.l #1, a1
	move.l top, d1
	sub.l a0, d1
	moveq #7, d0
	trap #gen
	move.l a0, d0
	sub.l a1, d0
	sub.l d0, top
bchar12:
	bra char
blkcpy:
	moveq #-121, d0
	bsr findmkr
	bne no7
	move.l a0, a2
	bsr chk89
	cmp.l a1, a2
	bcs.s blkcpy0
	cmp.l a0, a2
	bhi.s blkcpy0
	trap #err
	dc.b 0
.ascii  "Marker 7 must not be between markers 8 and 9"
	dc.b  0
.align 2
blkcpy0:
	bsr verify
	bne cmdcan
	move.l a0, d0
	sub.l a1, d0
	subq.l #1, d0
	bsr chkmem
	movem.l a1/d0, -(a7)
	move.l a2, a0
	lea 0(a0, d0.l), a1
	move.l top, d1
	sub.l a1, d1
	moveq #7, d0
	trap #gen
	movem.l (a7)+, d0/a1
	cmp.l a1, a2
	bhi.s blkcpy3
	add.l d0, a1
blkcpy3:
	lea 1(a1), a0
	move.l a2, a1
	move.l d0, d1
	moveq #7, d0
	trap #gen
	cmp.l stsc, a2
	bcc.s blkcpy1
	add.l d1, stsc
blkcpy1:
	cmp.l a6, a2
	bcc.s blkcpy2
	add.l d1, a6
blkcpy2:
bchar13:
	bra char
oscli:
	trap #msg
	dc.b 12
	dc.b  42
	dc.b  0
.align 2
	bsr curon
	bsr dltscrn
	lea ibuf, a0
	move.l #0x7e200a, d0
	move.w #255, d1
	trap #gen
	bcs.s bchar13
	moveq #4, d0
	trap #gen
	bra restart1
flnm1:
	trap #msg
	dc.b 12
.ascii  "Enter filename "
	dc.b  0
.align 2
	bsr curon
	bsr dltscrn
	lea ibuf, a0
	move.l #0x7e200a, d0
	move.w #10, d1
	trap #gen
	bra curoff
save:
	bsr.s flnm1
	bcs.s bchar13
	move.l page, a1
	move.l a1, a2
	lea entry-.-2(pc), a3
	move.l top, d1
	sub.l a1, d1
	moveq #0, d0
	trap #file
	move.l csrpos, a6
bchar14:
	bra.s bchar13
load:
	bsr.s flnm1
	bcs.s bchar14
	move.l page, a1
	moveq #1, d0
	trap #file
	move.l page, a0
	move.l a0, stsc
	move.l a0, a6
	moveq #-1, d0
load1:
	cmp.b (a0)+, d0
	bne.s load1
	move.l a0, top
bchar15:
	bra.s bchar14
blksav:
	bsr chk89
	movem.l a0/a1, -(a7)
	bsr flnm1
	bcs.s bchar15
	moveq #6, d0
	trap #file
	movem.l (a7)+, a0/a1
	addq.l #1, a1
	asl.w #8, d0
	move.b #3, d0
	move.w d0, d2
blksav1:
	cmp.l a0, a1
	bcc.s blksav2
	move.b (a1)+, d0
	swap d0
	move.w d2, d0
	trap #file
	bra.s blksav1
blksav2:
	move.b #255, d0
	swap d0
	move.w d2, d0
	trap #file
	move.w d2, d0
	move.b #4, d0
	trap #file
bchar16:
	bra.s bchar15
merge:
	moveq #-121, d0
	bsr findmkr
	bne no7
	move.l a0, a2
	bsr flnm1
	bcs.s bchar16
	moveq #5, d0
	trap #file
	asl.w #8, d0
	move.w d0, d2
	move.b #2, d2
merge1:
	moveq #0, d3
	lea ibuf, a0
merge2:
	move.w d2, d0
	trap #file
	cmp.b #255, d0
	seq d4
	beq.s merge3
	move.b d0, (a0)+
	addq.w #1, d3
	cmp.w #256, d3
	bcs.s merge2
merge3:
	move.l d3, d0
	bsr chkmem
	cmp.l stsc, a2
	bcc.s merge4
	add.l d3, stsc
merge4:
	cmp.l csrpos, a2
	bcc.s merge5
	add.l d3, csrpos
merge5:
	move.l a2, a0
	lea 0(a0, d3.w), a1
	move.l top, d1
	sub.l a1, d1
	moveq #7, d0
	trap #gen
	move.l a2, a1
	lea ibuf, a0
	move.l d3, d1
	moveq #7, d0
	trap #gen
	add.w d3, a2
	tst.b d4
	bpl.s merge1
	move.w d2, d0
	move.b #4, d0
	trap #file
	move.l csrpos, a6
bchar17:
	bra char
getsrchstr:
	bsr dltscrn
	trap #msg
	dc.b 12
.ascii  "Enter search string (up to 255 characters)."
	dc.b  13
	dc.b  10
.ascii "To enter a newline use |M, "
.ascii "to enter a paragraph use |A"
	dc.b  13
	dc.b  10
.ascii "To enter "
	dc.b  17
	dc.b  0
	dc.b  17
	dc.b  129
.ascii  "0123456789"
	dc.b  17
	dc.b  1
	dc.b  17
	dc.b  128
.ascii " use |0 |1 ... |9"
	dc.b  13
	dc.b  10
.ascii  "To enter | use ||"
	dc.b  13
	dc.b  10
	dc.b  10
	dc.b  0
.align 2
	bsr curon
	lea fndstr, a0
	move.w #255, d1
	move.l #0x7e200a, d0
	trap #gen
	bra curoff
dblbar:
	move.l a0, -(a7)
	moveq #13, d1
	moveq #0x7c, d2
dblbar1:
	cmp.b (a0)+, d1
	bne.s dblbar1
	lea -1(a0), a1
	move.l (a7), a0
dblbar2:
	cmp.l a1, a0
	bcc.s dblbar3
	move.b (a0)+, d0
	cmp.b d2, d0
	bne.s dblbar2
	move.l a0, a2
dblbar4:
	move.b (a2)+, -2(a2)
	cmp.l a1, a2
	bls.s dblbar4
	subq.l #1, a1
	move.b -1(a0), d0
	cmp.b d2, d0
	beq.s dblbar6
	cmp.b #0x30, d0
	bcs.s dblbar5
	cmp.b #0x39, d0
	bhi.s dblbar5
	eor.b #0x90, d0
dblbar5:
	and.b #0x9f, d0
	move.b d0, -1(a0)
dblbar6:
	bra.s dblbar2
dblbar3:
	move.l (a7)+, a0
	move.l a1, d0
	sub.l a0, d0
	rts
casesen:
	trap #msg
	dc.b 13
	dc.b  10
.ascii  "Case sensitive search? (Y/N) "
	dc.b  0
.align 2
	bsr curon
casesen0:
	trap #rdch
	bsr curoff
	bcs.s casesen1
	and.b #0xdf, d0
	cmp.b #0x59, d0
	beq.s casesen2
	cmp.b #0x4e, d0
	bne.s casesen0
	trap #wrch
	moveq #32, d0
casesen1:
	rts
casesen2:
	trap #wrch
	moveq #0, d0
	rts
search:
	lea fndstr, a1
	moveq #0, d1
	move.b fndstrlen, d1
	addq.l #1, a0
search1:
	moveq #0, d2
search2:
	move.b (a0)+, d3
	bmi.s search3
search4:
	sub.b 0(a1, d2.w), d3
	beq.s search5
	cmp.b d0, d3
	beq.s search6
	add.b d0, d3
	bne.s search1
search6:
	move.b 0(a1, d2.w), d3
	and.b #0xdf, d3
	cmp.b #0x40, d3
	bls.s search1
	cmp.b #0x5a, d3
	bhi.s search1
search5:
	addq.w #1, d2
	cmp.w d1, d2
	bcs.s search2
	sub.w d2, a0
	rts
search3:
	cmp.b #255, d3
	bne.s search4
	tst.b d3
	rts
find:
	bsr getsrchstr
	bcs.s bchar18
	bsr dblbar
	move.b d0, fndstrlen
	beq.s bchar18
	bsr casesen
	bcs.s bchar18
	move.b d0, csflg
	move.l page, a0
	subq.l #1, a0
find5:
	bsr.s search
find6:
	bne.s find0
find1:
	moveq #0, d0
	move.b fndstrlen, d0
	lea 0(a0, d0.w), a1
	cmp.l stsc, a1
	bls.s find2
	cmp.l a3, a1
	bhi.s find2
	move.l a0, a6
	cmp.l stsc, a6
	bcc.s find3
	move.l a6, stsc
find3:
bchar18:
	bra char
find2:
	move.l a0, a6
	moveq #6, d2
find4:
	bsr movup
	dbra d2, find4
	move.l a0, stsc
bchar19:
	bra.s bchar18
findnxt:
	tst.b fndstrlen
	beq.s nostring
	move.b csflg, d0
	move.l a6, a0
	bra.s find5
find0:
	bsr mw
	trap #msg
	dc.b 12
.ascii  "String not found"
	dc.b  0
.align 2
	bsr tw
bchar20:
	bra.s bchar19
nostring:
	bsr mw
	trap #msg
	dc.b 12
.ascii  "No search string defined"
	dc.b  0
.align 2
	bsr tw
bchar21:
	bra.s bchar20
findprev:
	tst.b fndstrlen
	beq.s nostring
	move.b csflg, d0
	move.l a6, a0
	bsr.s bsearch
	bra find6
bsearch:
	lea fndstr, a1
	moveq #0, d1
	move.b fndstrlen, d1
	move.l page, a2
bsearch1:
	move.w d1, d2
bsearch2:
	move.b -(a0), d3
	cmp.l a2, a0
	bcs.s bsearch3
	sub.b -1(a1, d2.w), d3
	beq.s bsearch5
	cmp.b d0, d3
	beq.s bsearch6
	add.b d0, d3
	bne.s bsearch1
bsearch6:
	move.b -1(a1, d2.w), d3
	and.b #0xdf, d3
	cmp.b #0x40, d3
	bls.s bsearch1
	cmp.b #0x5a, d3
	bhi.s bsearch1
bsearch5:
	subq.w #1, d2
	bne.s bsearch2
	rts
bsearch3:
	moveq #-1, d3
	rts
snr:
	bsr getsrchstr
	bcs.s bchar21
	bsr dblbar
	move.b d0, fndstrlen
	beq.s bchar21
	bsr.s getrepstr
	bcs.s bchar21
	bsr dblbar
	move.w d0, d6
	bsr casesen
	move.b d0, csflg
	bsr options
	bcs.s bchar21
	move.l page, a4
	move.l top, a5
	tst.l d7
	bpl.s snr1
	bsr chk89
	lea 1(a1), a4
	move.l a0, a5
snr1:
	move.l a4, a0
	move.b csflg, d0
snr4:
	bsr search
	bne.s snrend
	cmp.l a5, a0
	bhi.s snrend
	tst.w d7
	bpl.s snr2
	bsr show
	bsr confirm
	bcs.s bchar22
	beq.s snr4
snr2:
	bsr replace
	lea -1(a2), a0
	bra.s snr4
snrend:
	move.l csrpos, a6
bchar22:
	bra char
getrepstr:
	trap #msg
	dc.b 13
	dc.b  10
.ascii  "Enter string to replace with"
.ascii " (same format as search string)"
	dc.b  13
	dc.b  10
	dc.b  10
	dc.b  0
.align 2
	bsr curon
	lea ibuf, a0
	move.w #255, d1
	move.l #0x7e200a, d0
	trap #gen
	bra curoff
options:
	moveq #0, d7
	trap #msg
	dc.b 13
	dc.b  10
.ascii  "Global/Local? (G/L) "
	dc.b  0
.align 2
	bsr curon
options1:
	trap #rdch
	bcs.s options0
	and.b #0xdf, d0
	cmp.b #0x47, d0
	beq.s options2
	cmp.b #0x4c, d0
	bne.s options1
	bset #31, d7
options2:
	trap #wrch
	trap #msg
	dc.b 13
	dc.b  10
.ascii  "Conditional/Unconditional? (C/U) "
	dc.b  0
.align 2
options3:
	trap #rdch
	bcs.s options0
	and.b #0xdf, d0
	cmp.b #0x55, d0
	beq.s options4
	cmp.b #0x43, d0
	bne.s options3
	bset #15, d7
options4:
	moveq #0, d0
options0:
	bra curoff
confirm:
	bsr mw
	trap #msg
	dc.b 10
.ascii  "Replace? (Y/N)"
	dc.b  0
.align 2
	bsr tw
	moveq #31, d0
	trap #wrch
	move.b csrcol, d0
	trap #wrch
	move.b csrrow, d0
	trap #wrch
	bsr curon
conf1:
	trap #rdch
	bcs.s conf0
	and.b #0xdf, d0
	cmp.b #0x59, d0
	beq.s conf2
	cmp.b #0x4e, d0
	bne.s conf1
conf2:
	bsr curoff
	bsr mw
	trap #msg
	dc.b 10
	dc.b  0
.align 2
	bsr tw
	cmp.b #0x4e, d0
conf0:
	rts
replace:
	move.w d6, d0
	moveq #0, d5
	move.b fndstrlen, d5
	sub.w d5, d0
	ext.l d0
	bsr chkmem
	move.l a0, a2
	add.w d5, a0
	lea 0(a2, d6.w), a1
	cmp.l stsc, a1
	bcc.s rep3
	add.l d0, stsc
rep3:
	cmp.l csrpos, a1
	bcc.s rep4
	add.l d0, csrpos
rep4:
	move.l top, d1
	sub.l a1, d1
	moveq #7, d0
	trap #gen
	lea ibuf, a1
	move.l a2, a0
	move.w d6, d0
	bra.s rep2
rep1:
	move.b (a1)+, (a2)+
rep2:
	dbra d0, rep1
	rts
show:
	move.l a0, a6
	moveq #7, d2
show1:
	bsr movup
	dbra d2, show1
	move.l stsc, -(a7)
	move.l a0, stsc
	bsr eprt
	move.l (a7)+, stsc
	move.l a6, a0
	rts
dltscrn:
	movem.l a0/d0, -(a7)
	move.l scrn2, a0
	move.w #319, d0
dltsc1:
	clr.l (a0)+
	dbra d0, dltsc1
	movem.l (a7)+, a0/d0
	rts
flnm2:
	bsr.s dltscrn
	lea ibuf, a0
	moveq #0, d3
	trap #msg
	dc.b 12
.ascii  "Enter names of files to be printed. "
.ascii "<RETURN> to terminate list"
	dc.b  13
	dc.b  10
	dc.b  10
	dc.b  0
.align 2
flnm2a:
	trap #msg
.ascii "Enter name of file "
	dc.b  0
.align 2
	addq.w #1, d3
	move.l d3, d0
	bsr prtdec
	trap #msg
	dc.b 32
	dc.b  0
.align 2
	move.w #10, d1
	move.l #0x7e200a, d0
	bsr curon
	trap #gen
	bsr curoff
	bcs.s flnm2b
	cmp.b #13, (a0)
	beq.s flnm2b
	add.w #11, a0
	cmp.b #23, d3
	bcs.s flnm2a
	move.b #13, (a0)
flnm2b:
	rts
filest:
	lea ibuf, a6
	move.l a6, a0
	moveq #5, d0
	trap #file
	asl.w #8, d0
	move.b #2, d0
	move.w d0, d7
	move.l #0x00018b00, d0
	trap #gen
	rts
memst:
	move.l page, a6
	st d7
	rts
getch:
	tst.b d7
	bpl.s getch1
	move.b (a6)+, d0
	rts
getch1:
	move.w d7, d0
	trap #file
	cmp.b #255, d0
	beq.s getch2
	tst.b d0
	rts
getch2:
	move.w d7, d0
	move.b #4, d0
	trap #file
	add.w #11, a6
	exg a6, a0
	cmp.b #13, (a0)
	beq.s getch3
	moveq #5, d0
	trap #file
	exg a6, a0
	asl.w #8, d0
	move.b #2, d0
	move.w d0, d7
	bra.s getch1
getch3:
	move.l #0x02018b00, d0
	trap #gen
	move.b #255, d0
	exg a6, a0
	rts
default:
	move.b #0, lmrg
	move.b #80, llen
	move.b #0, jsmd
	move.b #0, lspc
	move.b #80, prtc
	move.b #66, lnpg
	move.b #3, pgmd
	rts
fileprt:
	moveq #2, d6
	bra.s fileprt1
fileprv:
	moveq #0, d6
fileprt1:
	bsr flnm2
	bcs char
	cmp.b #1, d3
	beq char
	bsr filest
	bra.s print
memprt:
	moveq #2, d6
	bra.s memprt1
memprv:
	moveq #0, d6
memprt1:
	bsr dltscrn
	bsr memst
print:
	bsr.s default
	clr.w pgnum
	st prtflg
	moveq #0, d5
	trap #msg
	dc.b 22
	dc.b  3
	dc.b  0
.align 2
	bsr curoff
	move.b d6, d0
	trap #wrch
print0:
	moveq #0, d6
print0a:
	moveq #0, d1
	move.b llen, d1
	lea linebuf, a0
	add.w d5, a0
	sub.w d5, d1
	move.b lmrg, lmrg2
	move.b llen, llen2
	move.b jsmd, jsmd2
	tst.b escflg
	bmi escape
print1:
	bsr getch
	bmi.s print2
	cmp.b #13, d0
	beq.s print3
	cmp.b #1, d0
	beq.s print4
	move.b d0, (a0)+
	dbra d1, print1
	moveq #0, d0
	move.b llen, d0
print5:
	bsr justify
	bsr.s output
	bra.s print6
print2:
	cmp.b #255, d0
	bne directive
	or.b #2, pgmd
	bsr.s finish
	bsr paging
	move.l csrpos, a6
	trap #msg
	dc.b 3
	dc.b  22
	dc.b  3
	dc.b  0
.align 2
	bsr screen
bchar23:
	bra char
finish:
	moveq #0, d0
	move.b llen, d0
	sub.b d1, d0
	move.b #0x20, (a0)
	bsr justify
	bra.s output
print3:
	moveq #0, d0
	move.b llen, d0
	sub.b d1, d0
	move.b #0x20, (a0)
	bra.s print5
print4:
	bsr.s finish
	cmp.b #1, jsmd
	beq.s print6
	cmp.b #2, jsmd
	beq.s print6
	lea linebuf, a0
	move.l #0x20202020, (a0)
	moveq #4, d5
print6:
	cmp.b lnpg, d6
	bcs print0a
	bsr paging
	bra print0
output:
	moveq #0x20, d0
	moveq #0, d1
	move.b lmrg, d1
	bra.s output1
output2:
	trap #wrch
output1:
	dbra d1, output2
	moveq #0, d1
	move.b llen, d1
	lea linebuf, a0
	bra.s output4
output3:
	move.b (a0)+, d0
	trap #wrch
output4:
	dbra d1, output3
	moveq #0, d1
	move.b prtc, d1
	sub.b lmrg, d1
	sub.b llen, d1
	moveq #0x20, d0
	bra.s output5
output6:
	trap #wrch
output5:
	dbra d1, output6
	lea linebuf, a1
	move.w d5, d1
	bra.s output7
output8:
	move.b (a0)+, (a1)+
output7:
	dbra d1, output8
	move.b lmrg2, lmrg
	move.b llen2, llen
	move.b jsmd2, jsmd
	moveq #10, d0
	moveq #0, d1
	move.b lspc, d1
	bra.s output10
output9:
	trap #wrch
output10:
	addq.b #1, d6
	cmp.b lnpg, d6
	bcc.s output11
	dbra d1, output9
jline0:
output11:
	rts
justify:
	move.b jsmd, d1
	beq jleft
	subq.b #1, d1
	beq jright
	subq.b #1, d1
	beq jcent
	cmp.b llen, d0
	bcs jleft
	bsr jleft1
	bcs.s jline0
	tst.b d5
	beq.s jline0
	moveq #32, d1
	moveq #-1, d2
jline1:
	addq.w #1, d2
	cmp.b 0(a0, d2.w), d1
	beq.s jline1
	moveq #0, d3
	move.b llen, d3
	sub.b d5, d3
jline9:
	subq.w #1, d3
	cmp.b 0(a0, d3.w), d1
	beq.s jline9
	addq.w #1, d3
	moveq #0, d4
	move.w d2, d0
jline2:
	addq.w #1, d0
	cmp.b 0(a0, d0.w), d1
	bne.s jline2
	cmp.b d3, d0
	bcc.s jline4
	addq.w #1, d4
jline3:
	addq.w #1, d0
	cmp.b 0(a0, d0.w), d1
	beq.s jline3
	bra.s jline2
jline4:
	tst.b d4
	beq.s jline0
	movem.l d5/d6/d7, -(a7)
jline5a:
	moveq #-1, d0
	asl.l d4, d0
	not.l d0
	move.l d0, rndf
jline5:
	move.l rndf, d6
	beq.s jline5a
jline5b:
	move.w rnd, d0
	mulu #1509, d0
	add.w #41, d0
	move.w d0, rnd
	and.l #0xffff, d0
	divu d4, d0
	swap d0
	bclr d0, d6
	beq.s jline5b
	move.l d6, rndf
	move.w d2, d6
jline6:
	addq.w #1, d6
	cmp.b 0(a0, d6.w), d1
	bne.s jline6
jline7:
	addq.w #1, d6
	cmp.b 0(a0, d6.w), d1
	beq.s jline7
	dbra d0, jline6
	moveq #0, d7
	move.b llen, d7
jline8:
	subq.w #1, d7
	move.b -1(a0, d7.w), 0(a0, d7.w)
	cmp.w d6, d7
	bgt.s jline8
	subq.b #1, d5
	bhi.s jline5
	movem.l (a7)+, d5/d6/d7
	rts
jleft:
	cmp.b llen, d0
	bcc.s jleft1
	lea linebuf, a0
	add.w d0, a0
	moveq #0x20, d1
jleft2:
	move.b d1, (a0)+
	addq.w #1, d0
	cmp.b llen, d0
	bne.s jleft2
jleft3:
	moveq #0, d5
	rts
jleft1:
	lea linebuf, a0
	moveq #0x20, d1
	cmp.b 0(a0, d0.w), d1
	beq.s jleft3
	moveq #-1, d2
jleft4:
	addq.w #1, d2
	cmp.b 0(a0, d2.w), d1
	beq.s jleft4
jleft5:
	subq.w #1, d0
	bmi.s jleft6
	cmp.b 0(a0, d0.w), d1
	bne.s jleft5
	cmp.b d2, d0
	bcs.s jleft6
	moveq #0, d5
	move.b llen, d5
	sub.b d0, d5
jmov:
	move.w d5, d0
jmov1:
	subq.b #1, d0
	beq.s jmov0
	moveq #0, d2
	move.b llen, d2
	move.w d2, d3
	add.b d0, d2
jmov2:
	move.b 0(a0, d3.w), 0(a0, d2.w)
	subq.w #1, d2
	subq.w #1, d3
	dbra d0, jmov2
jmov3:
	move.b d1, 0(a0, d3.w)
	addq.w #1, d3
	cmp.b llen, d3
	bcs.s jmov3
jmov0:
	rts
jleft6:
	moveq #1, d5
	move.w #1, ccr
	rts
jright:
	tst.b d0
	beq.s jleft
	cmp.b llen, d0
	bcc.s jright1
	moveq #0, d5
jright5:
	lea linebuf, a0
	moveq #0, d1
	move.b llen, d1
	bra.s jright3
jright2:
	move.b 0(a0, d0.w), 0(a0, d1.w)
jright3:
	subq.w #1, d1
	subq.w #1, d0
	bpl.s jright2
jright4:
	move.b #32, 0(a0, d1.w)
	subq.w #1, d1
	bpl.s jright4
	rts
jright1:
	bsr jleft1
	bcs.s jright0
	moveq #0, d0
	move.b llen, d0
	sub.b d5, d0
	tst.b d5
	bne.s jright5
jright0:
	rts
jcent:
	tst.b d0
	beq jleft
	cmp.b llen, d0
	bcc.s jcent1
	moveq #0, d5
jcent6:
	lea linebuf, a0
	moveq #0, d1
	move.b llen, d1
	sub.b d0, d1
	move.w d1, d2
	asr.w #1, d1
	sub.b d1, d2
	moveq #0, d3
	move.b llen, d3
jcent2:
	subq.w #1, d3
	move.b #32, 0(a0, d3.w)
	subq.b #1, d2
	bhi.s jcent2
	bra.s jcent4
jcent3:
	move.b 0(a0, d0.w), 0(a0, d3.w)
jcent4:
	subq.w #1, d3
	bmi.s jcent0
	subq.w #1, d0
	bpl.s jcent3
jcent5:
	move.b #32, 0(a0, d3.w)
	subq.w #1, d3
	bpl.s jcent5
jcent0:
	rts
jcent1:
	bsr jleft1
	bcs.s jcent0
	tst.b d5
	beq.s jcent0
	moveq #0, d0
	move.b llen, d0
	sub.b d5, d0
	bra.s jcent6
directive:
	and.w #0x7f, d0
	add.w d0, d0
	lea djt-.-2(pc), a1
	add.w 0(a1, d0.w), a1
	move.l d1, -(a7)
	jsr (a1)
	move.l (a7)+, d1
	bra print1
djt:
	dc.w setlm-djt, setlln-djt, setjmd-djt, setlsp-djt
	dc.w prtrctrl-djt, setprtc-djt, setlnpg-djt
	dc.w jmov0-djt, jmov0-djt, jmov0-djt
decin:
	moveq #0, d2
decin1:
	mulu #10, d2
	bsr getch
	sub.b #48, d0
	bcs.s decerr
	cmp.b #9, d0
	bhi.s decerr
	ext.w d0
	add.w d0, d2
	subq.b #1, d1
	bne.s decin1
	rts
decerr:
	trap #err
	dc.b 0
.ascii  "Number expected after directive"
	dc.b  0
.align 2
setlm:
	moveq #2, d1
	bsr.s decin
	move.b d2, lmrg2
	rts
setlln:
	moveq #2, d1
	bsr.s decin
	move.b d2, llen2
	rts
setjmd:
	bsr getch
	and.b #0xdf, d0
	cmp.b #0x4c, d0
	bne.s setjmd1
	move.b #0, jsmd2
	rts
setjmd1:
	cmp.b #0x52, d0
	bne.s setjmd2
	move.b #1, jsmd2
	rts
setjmd2:
	cmp.b #0x43, d0
	bne.s setjmd3
	move.b #2, jsmd2
	rts
setjmd3:
	cmp.b #0x4a, d0
	bne.s setpgmd
	move.b #3, jsmd2
	rts
setpgmd:
	cmp.b #0x50, d0
	bne.s newpage
	moveq #1, d1
	bsr decin
	cmp.b #7, d2
	bhi.s pgmderr
	move.b d2, pgmd
	rts
newpage:
	cmp.b #0x4e, d0
	bne.s dir2err
	addq.l #4, a7
	move.l (a7)+, d1
	bsr finish
	bsr.s newpg1
	bsr paging
	bra print0
newpg1:
	cmp.b lnpg, d6
	bcc.s newpg2
	addq.b #1, d6
	moveq #10, d0
	trap #wrch
	bra.s newpg1
newpg2:
	rts
dir2err:
	trap #err
	dc.b 0
.ascii  "L R C J P or N expected after directive 2"
	dc.b  0
.align 2
pgmderr:
	trap #err
	dc.b 0
.ascii  "Page mode must be between 0 and 7"
	dc.b  0
.align 2
setlsp:
	moveq #1, d1
	bsr decin
	move.b d2, lspc
	rts
prtrctrl:
	moveq #3, d1
	bsr decin
	cmp.w #255, d2
	bhi.s prtrctrl0
	moveq #1, d0
	trap #wrch
	move.b d2, d0
	trap #wrch
	rts
prtrctrl0:
	trap #err
	dc.b 0
.ascii  "Printer control code must be between 0 and 255"
	dc.b  0
.align 2
setprtc:
	moveq #3, d1
	bsr decin
	cmp.w #132, d2
	bhi.s setprtc0
	move.b d2, prtc
	rts
setprtc0:
	trap #err
	dc.b 0
.ascii  "Maximum 132 columns allowed"
	dc.b  0
.align 2
setlnpg:
	moveq #2, d1
	bsr decin
	move.b d2, lnpg
	rts
paging:
	addq.w #1, pgnum
	btst #0, pgmd
	beq.s paging1
	bsr newpg1
	moveq #10, d0
	trap #wrch
	moveq #0, d0
	move.w pgnum, d0
	moveq #1, d1
	cmp.w #9, d0
	bls.s paging2
	addq.b #1, d1
	cmp.w #99, d0
	bls.s paging2
	addq.b #1, d1
	cmp.w #999, d0
	bls.s paging2
	addq.b #1, d1
	cmp.w #9999, d0
	bls.s paging2
	addq.b #1, d1
paging2:
	moveq #0, d2
	move.b llen, d2
	sub.b d1, d2
	asr.w #1, d2
	add.b lmrg, d2
	move.w d2, d3
	add.w d1, d3
	moveq #32, d1
	exg d1, d0
	bra.s paging4
paging3:
	trap #wrch
paging4:
	dbra d2, paging3
	move.l d1, d0
	bsr prtdec
	moveq #0, d1
	move.b prtc, d1
	sub.w d3, d1
	moveq #32, d0
	bra.s paging6
paging5:
	trap #wrch
paging6:
	dbra d1, paging5
paging1:
	btst #1, pgmd
	beq.s paging7
	trap #rdch
paging7:
	btst #2, pgmd
	beq.s paging8
	moveq #12, d0
	trap #wrch
paging8:
	rts


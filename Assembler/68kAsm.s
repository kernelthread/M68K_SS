/* Assembler for 68000, 68010, 68020 processors
 *
 * Copyright (C) 1990-1991,2021 Dennis May
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

.equ	esc, 0x35
.equ	page, 0xc0
.equ	top, 0xc4
.equ	himem, 0xc8
.equ	cline, 0xdc
.equ	lomem, 0xd4
.equ	basvrtp, 0xd8
.equ	basvar, 0x106c
.equ	dest, 0x1010
.equ	npasses, 0x1040
.equ	lstflg, 0x1030
.equ	lbla, 0x1280
.equ	loc, 0x12e8
.equ	vartop, 0x12ec
.equ	pass, 0x12f0
.equ	proc, 0x12f1
.equ	undef, 0x12f2
.equ	endflg, 0x12f3
.equ	stinst, 0x12f4
.equ	objad, 0x12f8
.equ	lblad, 0x12fc
.equ	objbuf, 0x1200
.equ	ea1, 0x1220
.equ	ea2, 0x1222
.equ	ea3, 0x1224
.equ	ea4, 0x1226
.equ	ea5, 0x1228
.equ	od, 0x1230
.equ	bd, 0x1234
.equ	br, 0x1238
.equ	ir, 0x1239
.equ	sc, 0x123a
.equ	locinc, 0x123c
.equ	err, 0
.equ	wrch, 1
.equ	gen, 3
.equ	hex, 5
.equ	asci, 6
.equ	newl, 7
.equ	msg, 8

    .section .text
    .global START

mna:
.ascii "BC"
	dc.b  0xc4
.ascii  "D"
	dc.b  0xc4
.ascii  "DD"
	dc.b  0xd1
.ascii  "DD"
	dc.b  0xd8
.ascii  "N"
	dc.b  0xc4
.ascii "S"
	dc.b  0xcc
.ascii  "S"
	dc.b  0xd2
	dc.b  0
mnb:
.ascii "R"
	dc.b  0xc1
.ascii  "S"
	dc.b  0xd2
.ascii  "H"
	dc.b  0xc9
.ascii  "L"
	dc.b  0xd3
.ascii  "C"
	dc.b  0xc3
.ascii  "C"
	dc.b  0xd3
.ascii "N"
	dc.b  0xc5
.ascii  "E"
	dc.b  0xd1
.ascii  "V"
	dc.b  0xc3
.ascii  "V"
	dc.b  0xd3
.ascii  "P"
	dc.b  0xcc
.ascii  "M"
	dc.b  0xc9
.ascii "G"
	dc.b  0xc5
.ascii  "L"
	dc.b  0xd4
.ascii  "G"
	dc.b  0xd4
.ascii  "L"
	dc.b  0xc5
.ascii  "CH"
	dc.b  0xc7
.ascii  "CL"
	dc.b  0xd2
.ascii "SE"
	dc.b  0xd4
.ascii  "TS"
	dc.b  0xd4
.ascii  "FCH"
	dc.b  0xc7
.ascii  "FCL"
	dc.b  0xd2
.ascii  "FSE"
	dc.b  0xd4
.ascii  "FTS"
	dc.b  0xd4
.ascii "FEXT"
	dc.b  0xd5
.ascii  "FEXT"
	dc.b  0xd3
.ascii  "FIN"
	dc.b  0xd3
.ascii  "FFF"
	dc.b  0xcf
.ascii  "KP"
	dc.b  0xd4
	dc.b  0

mnc:
.ascii "ALL"
	dc.b  0xcd
.ascii  "A"
	dc.b  0xd3
.ascii  "AS"
	dc.b  0xb2
.ascii  "H"
	dc.b  0xcb
.ascii  "HK"
	dc.b  0xb2
.ascii "L"
	dc.b  0xd2
.ascii  "M"
	dc.b  0xd0
.ascii  "MP"
	dc.b  0xcd
.ascii  "MP"
	dc.b  0xb2
	dc.b  0

mnd:
.ascii "BR"
	dc.b  0xc1
.ascii  "BH"
	dc.b  0xc9
.ascii  "BL"
	dc.b  0xd3
.ascii  "BC"
	dc.b  0xc3
.ascii  "BC"
	dc.b  0xd3
.ascii "BN"
	dc.b  0xc5
.ascii  "BE"
	dc.b  0xd1
.ascii  "BV"
	dc.b  0xc3
.ascii  "BV"
	dc.b  0xd3
.ascii  "BP"
	dc.b  0xcc
.ascii  "BM"
	dc.b  0xc9
.ascii "BG"
	dc.b  0xc5
.ascii  "BL"
	dc.b  0xd4
.ascii  "BG"
	dc.b  0xd4
.ascii  "BL"
	dc.b  0xc5
.ascii  "IV"
	dc.b  0xd3
.ascii  "IVS"
	dc.b  0xcc
.ascii "IV"
	dc.b  0xd5
.ascii  "IVU"
	dc.b  0xcc
	dc.b  0

mne:
.ascii "O"
	dc.b  0xd2
.ascii  "X"
	dc.b  0xc7
.ascii  "X"
	dc.b  0xd4
.ascii  "XT"
	dc.b  0xc2
	dc.b  0

mnf:
	dc.b 0

mni:
.ascii "LLEGA"
	dc.b  0xcc
	dc.b  0

mnj:
.ascii "M"
	dc.b  0xd0
.ascii  "S"
	dc.b  0xd2
	dc.b  0

mnl:
.ascii "E"
	dc.b  0xc1
.ascii  "IN"
	dc.b  0xcb
.ascii  "S"
	dc.b  0xcc
.ascii  "S"
	dc.b  0xd2
	dc.b  0

mnm:
.ascii "OV"
	dc.b  0xc5
.ascii  "OVE"
	dc.b  0xc3
.ascii  "OVE"
	dc.b  0xcd
.ascii  "OVE"
	dc.b  0xd0
.ascii  "OVE"
	dc.b  0xd1
.ascii "OVE"
	dc.b  0xd3
.ascii  "UL"
	dc.b  0xd3
.ascii  "UL"
	dc.b  0xd5
	dc.b  0

mnn:
.ascii "BC"
	dc.b  0xc4
.ascii  "E"
	dc.b  0xc7
.ascii  "EG"
	dc.b  0xd8
.ascii  "O"
	dc.b  0xd0
.ascii  "O"
	dc.b  0xd4
	dc.b  0

mno:
	dc.b 0xd2
	dc.b  0

mnp:
.ascii "AC"
	dc.b  0xcb
.ascii  "E"
	dc.b  0xc1
	dc.b  0

mnr:
.ascii "ESE"
	dc.b  0xd4
.ascii  "O"
	dc.b  0xcc
.ascii  "O"
	dc.b  0xd2
.ascii  "OX"
	dc.b  0xcc
.ascii  "OX"
	dc.b  0xd2
.ascii "T"
	dc.b  0xc4
.ascii  "T"
	dc.b  0xcd
.ascii  "T"
	dc.b  0xc5
.ascii  "T"
	dc.b  0xd2
.ascii  "T"
	dc.b  0xd3
	dc.b  0

mns:
.ascii "BC"
	dc.b  0xc4
	dc.b  0xd4
	dc.b  0xc6
.ascii  "H"
	dc.b  0xc9
.ascii  "L"
	dc.b  0xd3
.ascii  "C"
	dc.b  0xc3
.ascii "C"
	dc.b  0xd3
.ascii  "N"
	dc.b  0xc5
.ascii  "E"
	dc.b  0xd1
.ascii  "V"
	dc.b  0xc3
.ascii  "V"
	dc.b  0xd3
.ascii  "P"
	dc.b  0xcc
.ascii "M"
	dc.b  0xc9
.ascii  "G"
	dc.b  0xc5
.ascii  "L"
	dc.b  0xd4
.ascii  "G"
	dc.b  0xd4
.ascii  "L"
	dc.b  0xc5
.ascii  "TO"
	dc.b  0xd0
.ascii "U"
	dc.b  0xc2
.ascii  "UB"
	dc.b  0xd1
.ascii  "UB"
	dc.b  0xd8
.ascii  "WA"
	dc.b  0xd0
	dc.b  0

mnt:
.ascii "A"
	dc.b  0xd3
.ascii  "RA"
	dc.b  0xd0
.ascii  "RAP"
	dc.b  0xd4
.ascii  "RAP"
	dc.b  0xc6
.ascii  "RAPH"
	dc.b  0xc9
.ascii "RAPL"
	dc.b  0xd3
.ascii  "RAPC"
	dc.b  0xc3
.ascii  "RAPC"
	dc.b  0xd3
.ascii  "RAPN"
	dc.b  0xc5
.ascii  "RAPE"
	dc.b  0xd1
.ascii "RAPV"
	dc.b  0xc3
.ascii  "RAPV"
	dc.b  0xd3
.ascii  "RAPP"
	dc.b  0xcc
.ascii  "RAPM"
	dc.b  0xc9
.ascii  "RAPG"
	dc.b  0xc5
.ascii "RAPL"
	dc.b  0xd4
.ascii  "RAPG"
	dc.b  0xd4
.ascii  "RAPL"
	dc.b  0xc5
.ascii  "RAP"
	dc.b  0xd6
.ascii  "S"
	dc.b  0xd4
	dc.b  0

mnu:
.ascii "NL"
	dc.b  0xcb
.ascii  "NP"
	dc.b  0xcb
	dc.b  0
.align 2
mt:
	dc.w mna-mt, mnb-mt, mnc-mt, mnd-mt, mne-mt, mnf-mt, mnf-mt, mnf-mt
	dc.w mni-mt, mnj-mt, mnf-mt, mnl-mt, mnm-mt, mnn-mt, mno-mt, mnp-mt
	dc.w mnf-mt, mnr-mt, mns-mt, mnt-mt, mnu-mt
	dc.w mnf-mt, mnf-mt, mnf-mt, mnf-mt, mnf-mt
ot:
	dc.b 0
	dc.b  7
	dc.b  36
	dc.b  45
	dc.b  64
	dc.b  68
	dc.b  68
	dc.b  68
	dc.b  68
	dc.b  69
	dc.b  71
	dc.b  71
	dc.b  75
	dc.b  83
	dc.b  88
	dc.b  89
	dc.b  91
	dc.b 91
	dc.b  101
	dc.b  123
	dc.b  143
	dc.b  145
	dc.b  145
	dc.b  145
	dc.b  145
	dc.b  145
gt:
	dc.b 6
	dc.b  7
	dc.b  16
	dc.b  6
	dc.b  10
	dc.b  5
	dc.b  5
	dc.b  34
	dc.b  34
	dc.b  34
	dc.b  34
	dc.b  34
	dc.b  34
	dc.b  34
	dc.b  34
	dc.b  34
	dc.b  34
	dc.b  34
	dc.b  34
	dc.b  34
	dc.b  34
	dc.b  34
	dc.b  34
	dc.b 12
	dc.b  12
	dc.b  12
	dc.b  12
	dc.b  0x8d
	dc.b  0x8d
	dc.b  0x8d
	dc.b  0x8d
	dc.b  0x8e
	dc.b  0x8e
	dc.b  0x8f
	dc.b  0x8e
	dc.b  0x81
	dc.b  0x94
	dc.b  0x95
	dc.b  0x96
	dc.b  19
	dc.b  0x92
	dc.b  4
	dc.b  8
	dc.b  23
	dc.b  0x92
	dc.b 11
	dc.b  11
	dc.b  11
	dc.b  11
	dc.b  11
	dc.b  11
	dc.b  11
	dc.b  11
	dc.b  11
	dc.b  11
	dc.b  11
	dc.b  11
	dc.b  11
	dc.b  11
	dc.b  11
	dc.b  29
	dc.b  0x9e
	dc.b  29
	dc.b  0x9e
	dc.b 9
	dc.b  3
	dc.b  3
	dc.b  0x83
	dc.b  0
	dc.b  4
	dc.b  4
	dc.b  24
	dc.b  31
	dc.b  5
	dc.b  5
	dc.b  33
	dc.b  0x63
	dc.b  26
	dc.b  27
	dc.b  17
	dc.b  0x59
	dc.b  28
	dc.b  28
	dc.b  4
	dc.b  4
	dc.b  4
	dc.b  0
	dc.b  4
	dc.b  10
	dc.b  0xa0
	dc.b 4
	dc.b  0
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b  0x41
	dc.b  0x83
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  6
	dc.b  36
	dc.b  36
	dc.b  36
	dc.b  36
	dc.b  36
	dc.b  36
	dc.b  36
	dc.b  36
	dc.b  36
	dc.b  36
	dc.b  36
	dc.b  36
	dc.b  36
	dc.b  36
	dc.b  36
	dc.b  36
	dc.b  1
	dc.b  7
	dc.b  16
	dc.b  6
	dc.b 3
	dc.b  4
	dc.b  1
	dc.b  0x82
	dc.b  0x82
	dc.b  0x82
	dc.b  0x82
	dc.b  0x82
	dc.b  0x82
	dc.b  0x82
	dc.b  0x82
	dc.b  0x82
	dc.b  0x82
	dc.b  0x82
	dc.b  0x82
	dc.b  0x82
	dc.b  0x82
	dc.b  0x82
	dc.b  0x82
	dc.b  0
	dc.b  4
	dc.b  3
	dc.b  0xa0

pgt:
	dc.b 0
	dc.b  1
	dc.b  0
	dc.b  2
	dc.b  1
	dc.b  0
	dc.b  1
	dc.b  0
	dc.b  1
	dc.b  2
	dc.b  3
	dc.b  4
	dc.b  5
	dc.b  6
	dc.b  7
	dc.b  8
	dc.b  9
	dc.b  10
	dc.b  11
	dc.b  12
	dc.b  13
	dc.b  14
	dc.b  15
	dc.b 1
	dc.b  2
	dc.b  3
	dc.b  0
	dc.b  1
	dc.b  2
	dc.b  3
	dc.b  0
	dc.b  0
	dc.b  1
	dc.b  0
	dc.b  2
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  1
	dc.b 0
	dc.b  1
	dc.b  2
	dc.b  3
	dc.b  4
	dc.b  5
	dc.b  6
	dc.b  7
	dc.b  8
	dc.b  9
	dc.b  10
	dc.b  11
	dc.b  12
	dc.b  13
	dc.b  14
	dc.b  1
	dc.b  1
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  1
	dc.b  2
	dc.b  1
	dc.b  1
	dc.b  2
	dc.b 0
	dc.b  0
	dc.b  2
	dc.b  3
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  1
	dc.b  0
	dc.b  4
	dc.b  5
	dc.b  7
	dc.b  0
	dc.b  6
	dc.b  0
	dc.b  0
	dc.b  3
	dc.b  2
	dc.b  4
	dc.b  5
	dc.b  6
	dc.b  7
	dc.b  2
	dc.b  3
	dc.b  3
	dc.b  4
	dc.b  5
	dc.b 1
	dc.b  0
	dc.b  1
	dc.b  2
	dc.b  3
	dc.b  4
	dc.b  5
	dc.b  6
	dc.b  7
	dc.b  8
	dc.b  9
	dc.b  10
	dc.b  11
	dc.b  12
	dc.b  13
	dc.b  14
	dc.b  15
	dc.b  3
	dc.b  0
	dc.b  1
	dc.b  3
	dc.b  4
	dc.b  8
	dc.b 1
	dc.b  0
	dc.b  1
	dc.b  2
	dc.b  3
	dc.b  4
	dc.b  5
	dc.b  6
	dc.b  7
	dc.b  8
	dc.b  9
	dc.b  10
	dc.b  11
	dc.b  12
	dc.b  13
	dc.b  14
	dc.b  15
	dc.b  6
	dc.b  9
	dc.b  5
	dc.b  1
.align 2
match:
	movem.l a1/d1/d2, -(a7)
	moveq #0, d0
mtch0:
	move.l a6, a1
mtch1:
	move.b (a1)+, d1
	move.b (a0)+, d2
	eor.b d1, d2
	and.b #0xdf, d2
	beq.s mtch1
	neg.b d2
	bvs.s mtchf
mtchnf:
	subq.l #1, a0
mtch2:
	tst.b (a0)+
	bpl.s mtch2
	addq.w #1, d0
	tst.b (a0)
	bne.s mtch0
	beq.s mtchnd
mtchf:
	move.b (a1), d1
	cmp.b #0x30, d1
	bcs.s mtchf2
	cmp.b #0x39, d1
	bls.s mtchnf
	and.b #0xdf, d1
	cmp.b #0x41, d1
	bcs.s mtchf2
	cmp.b #0x5a, d1
	bls.s mtchnf
mtchf2:
	move.l a1, a6
	move.w #1, ccr
mtchnd:
	movem.l (a7)+, a1/d1/d2
	rts
gtisz:
	bsr.s gtsz0
	cmp.b #2, d0
	blt.s szinv
	rts
gtsz0:
	moveq #2, d0
	bra.s gtsz1
gtsz:
	moveq #0, d0
gtsz1:
	cmp.b #46, (a6)
	bne.s gtsz2
	addq.l #1, a6
	moveq #-33, d0
	and.b (a6)+, d0
	cmp.b #0x42, d0
	bne.s gtsz3
	moveq #1, d0
gtsz2:
	rts
gtsz3:
	cmp.b #0x57, d0
	bne.s gtsz4
	moveq #2, d0
	rts
gtsz4:
	cmp.b #0x4c, d0
	bne.s gtsz5
	moveq #4, d0
	rts
gtsz5:
	cmp.b #0x53, d0
	bne.s szinv
	moveq #-128, d0
	rts
szinv:
	trap #err
	dc.b 0
.ascii  "Invalid size code"
	dc.b  0
	dc.b  0
.align 2
optab:
	dc.l 0, 0, 0, 0, 0, 0, 0, 0
	dc.b 255
	dc.b  0
	dc.b  8
	dc.b  0
	dc.b  6
	dc.b  7
	dc.b  0
	dc.b  0
	dc.b  10
	dc.b  0
	dc.b  9
	dc.b  3
	dc.b  0
	dc.b  4
	dc.b  0
	dc.b  0
	dc.b 1
	dc.b  1
	dc.b  1
	dc.b  1
	dc.b  1
	dc.b  1
	dc.b  1
	dc.b  1
	dc.b  1
	dc.b  1
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b 0
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b 2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b 0
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b 2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  5
	dc.b  0
.align 2
opjt:
	dc.w syntax-opjt, num-opjt, var-opjt, operand-opjt, minus-opjt
	dc.w not-opjt, hexnum-opjt, bin-opjt, char-opjt, lctr-opjt, brkt-opjt
operand:
	moveq #0, d0
	move.b (a6)+, d0
	bmi.s syntax
	lea optab-.-2(pc), a0
	move.b 0(a0, d0.w), d0
	bmi.s operand
	lea opjt-.-2(pc), a0
	add.w d0, d0
	add.w 0(a0, d0.w), a0
	jmp (a0)
syntax:
	trap #err
	dc.b 16
.ascii  "Syntax error"
	dc.b  0
.align 2
minus:
	bsr.s operand
	neg.l d0
	rts
not:
	bsr.s operand
	not.l d0
	rts
hexnum:
	move.l a6, a0
	moveq #0x16, d0
	trap #gen
	move.l a0, a6
	rts
bbaaddbin:
	trap #err
	dc.b 0
.ascii  "Bad binary"
	dc.b  0
.align 2
bin:
	move.b (a6), d0
	sub.b #48, d0
	bcs.s bbaaddbin
	cmp.b #1, d0
	bhi.s bbaaddbin
	moveq #0, d0
bin1:
	move.b (a6)+, d1
	sub.b #48, d1
	bcs.s bin2
	cmp.b #1, d1
	bhi.s bin2
	add.l d0, d0
	bcs.s toobig
	or.b d1, d0
	bra.s bin1
bin2:
	subq.l #1, a6
	rts
toobig:
	trap #err
	dc.b 20
.ascii  "Too big"
	dc.b  0
	dc.b  0
.align 2
char:
	moveq #0, d0
char1:
	move.b (a6)+, d1
	cmp.b #0x22, d1
	beq.s char2
	cmp.b #13, d1
	beq.s msngquot
char3:
	rol.l #8, d0
	tst.b d0
	bne.s toobig
	move.b d1, d0
	bra.s char1
char2:
	cmp.b (a6)+, d1
	beq.s char3
	subq.l #1, a6
	rts
msngquot:
	trap #err
	dc.b 0
.ascii  "Missing "
	dc.b  0x22
	dc.b  0
	dc.b  0
.align 2
lctr:
	move.l loc, d0
	rts
brkt:
	bsr expb
	cmp.b #41, (a6)+
	bne syntax
	rts
var:
	subq.l #1, a6
	bsr.s fndv0
	bcc.s var0
	move.l a1, a6
	move.l 2(a2), d0
	rts
var0:
	tst.b pass
	beq.s nosuch
	st undef
var1:
	move.b (a6)+, d0
	cmp.b #48, d0
	bcs.s var2
	cmp.b #57, d0
	bls.s var1
	cmp.b #65, d0
	bcs.s var2
	and.b #0xdf, d0
	cmp.b #90, d0
	bls.s var1
var2:
	subq.l #1, a6
	moveq #1, d0
	rts
nosuch:
	trap #err
	dc.b 0
.ascii  "Undefined label"
	dc.b  0
	dc.b  0
.align 2
bbaaddvrnm:
	trap #err
	dc.b 0
.ascii  "Bad label name"
	dc.b  0
.align 2
fndv0:
	moveq #-33, d0
	and.b (a6)+, d0
	sub.b #0x41, d0
	bcs.s bbaaddvrnm
	cmp.b #25, d0
	bhi.s bbaaddvrnm
fndv:
	ext.w d0
	asl.w #2, d0
	lea lbla, a0
	add.w d0, a0
fndv1:
	move.l (a0), d0
	beq.s vrnf
	move.l d0, a0
	move.l a6, a1
	lea 4(a0), a2
fndv2:
	move.b (a1)+, d0
	cmp.b #0x40, d0
	bls.s fndv3
	and.b #0xdf, d0
fndv3:
	cmp.b (a2)+, d0
	beq.s fndv2
	tst.b -(a2)
	bne.s fndv1
	cmp.b #48, d0
	bcs.s varf
	cmp.b #57, d0
	bls.s fndv1
	cmp.b #65, d0
	bcs.s varf
	cmp.b #90, d0
	bls.s fndv1
varf:
	subq.l #1, a1
	move.l a2, d0
	addq.l #2, d0
	and.w #0xfffe, d0
	move.l d0, a2
	move.w #1, ccr
vrnf:
	rts
num:
	moveq #0, d0
	subq.l #1, a6
num1:
	move.b (a6)+, d1
	sub.b #48, d1
	bcs.s num2
	cmp.b #9, d1
	bhi.s num2
	add.l d0, d0
	bcs.s num3
	move.l d0, d2
	add.l d0, d0
	bcs.s num3
	add.l d0, d0
	bcs.s num3
	add.l d2, d0
	bcs.s num3
	ext.w d1
	ext.l d1
	add.l d1, d0
num3:
	bcs toobig
	bra.s num1
num2:
	subq.l #1, a6
	rts
exp1:
	bsr.s exp
	tst.b undef
	bpl.s exp0
	move.l loc, d0
	rts
expr:
	bsr.s exp
	tst.b undef
	bpl.s exp0
	moveq #1, d0
exp0:
	rts
expt:
	dc.b 0x2b
	dc.b  0x2d
	dc.b  0x2a
	dc.b  0x2f
	dc.b  0x5c
	dc.b  0x26
	dc.b  0x21
	dc.b  0x7c
	dc.b  0x3e
	dc.b  0x3c
.align 2
.equ	nops, 10
expp:
	dc.b 4
	dc.b  4
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b  2
	dc.b  1
	dc.b  1
	dc.b  6
	dc.b  6
.align 2
expjt:
	dc.w add-expjt, sub-expjt, mul-expjt, div-expjt, mod-expjt
	dc.w and-expjt, or-expjt, eor-expjt, shr-expjt, shl-expjt
exp:
	clr.b undef
expb:
	clr.w -(a7)
expr1:
	bsr operand
	lea expt-.-2(pc), a0
expr2:
	move.b (a6)+, d1
	cmp.b #32, d1
	beq.s expr2
	moveq #nops-1, d2
expr3:
	cmp.b (a0)+, d1
	dbeq d2, expr3
	bne.s exprend
	moveq #nops-1, d1
	sub.w d2, d1
	lea expp-.-2(pc), a0
	move.b 0(a0, d1.w), d3
	lea expjt-.-2(pc), a0
	add.w d1, d1
	add.w 0(a0, d1.w), a0
expr4:
	cmp.b (a7), d3
	bls.s exprdo
	move.l a0, -(a7)
	move.l d0, -(a7)
	move.b d3, -(a7)
	bra.s expr1
exprdo:
	addq.l #2, a7
	move.l (a7)+, d1
	exg d1, d0
	move.l (a7)+, a1
	jsr (a1)
	bra.s expr4
exprend:
	tst.b (a7)+
	beq.s expr5
	move.l (a7)+, d1
	exg d1, d0
	move.l (a7)+, a1
	jsr (a1)
	bra.s exprend
expr5:
	subq.l #1, a6
	rts
add:
	add.l d1, d0
	rts
sub:
	sub.l d1, d0
	rts
and:
	and.l d1, d0
	rts
or:
	or.l d1, d0
	rts
eor:
	eor.l d1, d0
	rts
shr:
	lsr.l d1, d0
	rts
shl:
	lsl.l d1, d0
	rts
mul:
	bsr.s absvals
	move.l d0, d2
	moveq #0, d0
	moveq #31, d4
mul2:
	add.l d0, d0
	bvs.s mul5
	add.l d1, d1
	bcc.s mul3
	add.l d2, d0
	bvs.s mul5
mul3:
	dbra d4, mul2
mul1:
	tst.l d5
	bpl.s mul4
	neg.l d0
mul4:
	rts
mul5:
	bra toobig
absvals:
	move.l d0, d5
	eor.l d1, d5
	tst.l d0
	bpl.s absv1
	neg.l d0
absv1:
	tst.l d1
	bpl.s absv2
	neg.l d1
absv2:
	rts
div0:
	trap #err
	dc.b 0
.ascii  "Division by zero"
	dc.b  0
.align 2
idiv:
	tst.l d0
	beq.s div0
	moveq #31, d4
	moveq #0, d2
idiv1:
	add.l d0, d0
	addx.l d2, d2
	cmp.l d1, d2
	bcs.s idiv2
	sub.l d1, d2
	addq.w #1, d0
idiv2:
	dbra d4, idiv1
	rts
mod:
	bsr.s idiv
	move.l d2, d0
	rts
div:
	bsr.s absvals
	bsr.s idiv
	bra.s mul1
regtab:
	dc.l 0x44b044b1, 0x44b244b3, 0x44b444b5, 0x44b644b7
	dc.l 0x41b041b1, 0x41b241b3, 0x41b441b5, 0x41b641b7, 0x53d050c3
.ascii "S"
	dc.b  0xd2
.ascii  "CC"
	dc.b  0xd2
.ascii  "US"
	dc.b  0xd0
.ascii  "IS"
	dc.b  0xd0
.ascii  "MS"
	dc.b  0xd0
.ascii  "VB"
	dc.b  0xd2
.ascii "SF"
	dc.b  0xc3
.ascii  "DF"
	dc.b  0xc3
.ascii  "CAC"
	dc.b  0xd2
.ascii  "CAA"
	dc.b  0xd2
	dc.b  0
.align 2
regptab:
	dc.l 0, 0, 0, 0
	dc.b 0
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  2
	dc.b  2
	dc.b  1
	dc.b  1
	dc.b  1
	dc.b  2
	dc.b  2
.align 2
regcode:
	dc.b 0
	dc.b  1
	dc.b  2
	dc.b  3
	dc.b  4
	dc.b  5
	dc.b  6
	dc.b  7
	dc.b  8
	dc.b  9
	dc.b  10
	dc.b  11
	dc.b  12
	dc.b  13
	dc.b  14
	dc.b  15
	dc.b 15
	dc.b  128
	dc.b  192
	dc.b  193
	dc.b  240
	dc.b  241
	dc.b  242
	dc.b  243
	dc.b  244
	dc.b  245
	dc.b  246
	dc.b  247
.align 2
bbaadd0:
	bra bbaadd
datreg:
	bsr.s reg
	bcc.s bbaadd0
	cmp.b #7, d0
	bhi.s bbaadd0
	rts
adreg:
	bsr.s reg
	bcc.s bbaadd0
	cmp.b #7, d0
	bls.s bbaadd0
	cmp.b #15, d0
	bhi.s bbaadd0
	rts
genreg:
	bsr.s reg
	bcc.s bbaadd0
	cmp.b #15, d0
	bhi.s bbaadd0
	rts
reg:
	movem.l a0/d1, -(a7)
	bsr ns2
	lea regtab-.-2(pc), a0
	bsr match
	bcc.s reg0
	lea regptab-.-2(pc), a0
	move.b proc, d1
	cmp.b 0(a0, d0.w), d1
	bcs.s procerr
	lea regcode-.-2(pc), a0
	move.b 0(a0, d0.w), d0
	move.w #1, ccr
reg0:
	movem.l (a7)+, a0/d1
reg0a:
	rts
chk68020:
	cmp.b #2, proc
	bcc.s reg0a
procerr:
	trap #err
	dc.b 0
.ascii  "Not on this processor"
	dc.b  0
	dc.b  0
.align 2
getea:
	moveq #0, d6
	bsr.s reg
	bcc.s getea0
	cmp.b #128, d0
	beq.s bbaadd
	moveq #0, d1
	rts
bbaadd:
	trap #err
	dc.b 0
.ascii  "Bad instruction"
	dc.b  0
	dc.b  0
.align 2
cm:
	cmp.b #44, (a6)+
	bne.s bbaadd
	rts
getea0:
	move.b (a6)+, d0
	cmp.b #0x23, d0
	bne.s getea1
	bsr expr
	move.l d0, ea1
	moveq #0x3c, d0
	rts
getea1:
	cmp.b #0x2d, d0
	bne.s getea2
	lea -1(a6), a1
	cmp.b #0x28, (a6)+
	bne.s getea3
	bsr reg
	bcc.s absaddr
	subq.w #8, d0
	bcs.s bbaadd
	cmp.b #7, d0
	bhi.s bbaadd
	cmp.b #0x29, (a6)+
	bne.s bbaadd
	add.b #0x20, d0
	moveq #0, d1
	rts
absaddr:
	move.l a1, a6
absaddr0:
	bsr expr
absaddr1:
	move.w d0, d1
	ext.l d1
	cmp.l d1, d0
	bne.s abslong
	move.w d0, ea1
	moveq #0x38, d0
	moveq #1, d1
	rts
abslong:
	move.l d0, ea1
	moveq #0x39, d0
	moveq #2, d1
	rts
getea3:
	move.l a1, a6
getea3a:
	bsr expr
	move.l d0, od
	move.l d0, bd
	bset #31, d6
	move.b (a6)+, d0
getea2:
	cmp.b #0x28, d0
	beq.s getea4
	subq.l #1, a6
	move.l od, d0
	tst.l d6
	bmi.s absaddr1
	bra.s getea3a
getea4:
	cmp.b #0x5b, (a6)
	beq memind
getea5:
	bsr reg
	bcs.s regind
	tst.l d6
	bmi.s bbaadd0a
	bsr expr
	move.l d0, bd
	bset #31, d6
	cmp.b #0x2c, (a6)+
	beq.s getea5
bbaadd0a:
	bra bbaadd
getsc:
	moveq #0, d0
	cmp.b #0x2a, (a6)
	bne.s getsc0
	addq.l #1, a6
	move.b (a6)+, d0
	sub.b #49, d0
	bcs.s bbaaddsc
	beq.s getsc0
	cmp.b #1, d0
	beq.s getsc1
	cmp.b #3, d0
	beq.s getsc2
	cmp.b #7, d0
	bne.s bbaaddsc
	moveq #3, d0
	bra.s getsc1
getsc2:
	moveq #2, d0
getsc1:
	bsr chk68020
getsc0:
	rts
bbaaddsc:
	trap #err
	dc.b 0
.ascii  "Bad scale factor"
	dc.b  0
.align 2
regind:
	move.b d0, ir
	move.b d0, br
	cmp.b #128, d0
	bhi.s bbaadd0a
	beq.s pcrel
	cmp.b #8, d0
	bcs.s index0
	cmp.b #46, (a6)
	bne.s regind0
	bsr gtisz
	beq.s index1
	bset #7, ir
regind0:
	bsr.s getsc
	move.b d0, sc
	bne.s index2
pcrel:
	bset #7, d6
	move.b (a6)+, d0
	cmp.b #0x2c, d0
	beq.s index
	cmp.b #0x29, d0
	bne.s bbaadd1
	cmp.b #0x2b, (a6)
	bne encdea
	addq.l #1, a6
	tst.b br
	bmi.s bbaadd1
	tst.l d6
	bpl.s postinc0
	tst.l od
	bne.s bbaadd1
postinc0:
	moveq #0x10, d0
	add.b br, d0
	moveq #0, d1
	rts
index:
	bsr reg
	bcc.s bbaadd1
	tst.b d0
	bmi.s bbaadd1
	move.b d0, ir
index0:
	bsr gtisz
	beq.s index1
	bset #7, ir
index1:
	bsr getsc
	move.b d0, sc
index2:
	bset #15, d6
	cmp.b #0x29, (a6)+
	beq encdea
bbaadd1:
	bra.s bbaadd2
memind:
	addq.l #1, a6
	bsr chk68020
	bset #30, d6
	bsr reg
	bcs.s memind0
	bsr expr
	move.l d0, bd
	bset #29, d6
	move.b (a6)+, d0
	cmp.b #0x2c, d0
	beq.s memind1
	cmp.b #0x5d, d0
	beq postindex
bbaadd2:
	bra bbaadd
memind1:
	bsr reg
	bcc.s bbaadd2
memind0:
	move.b d0, ir
	move.b d0, br
	cmp.b #128, d0
	bhi.s bbaadd2
	beq.s pcrelind
	cmp.b #8, d0
	bcs.s preindex0
	cmp.b #46, (a6)
	bne.s memind3
	bsr gtisz
	beq.s preindex1
	bset #7, ir
memind3:
	bsr getsc
	move.b d0, sc
	bne.s preindex2
pcrelind:
	bset #7, d6
	move.b (a6)+, d0
	cmp.b #0x2c, d0
	beq.s preindex
	cmp.b #0x5d, d0
	beq.s postindex
bbaadd3:
	bra.s bbaadd2
preindex:
	bsr reg
	bcc.s bbaadd3
	move.b d0, ir
	bmi.s bbaadd3
preindex0:
	bsr gtisz
	beq.s preindex1
	bset #7, ir
preindex1:
	bsr getsc
	move.b d0, sc
preindex2:
	bset #28, d6
	bset #15, d6
	cmp.b #0x5d, (a6)+
	beq.s outerdisp
bbaadd4:
	bra.s bbaadd3
postindex:
	move.b (a6)+, d0
	cmp.b #0x29, d0
	beq.s encdea
	cmp.b #0x2c, d0
	bne.s bbaadd4
	bsr reg
	bcc.s outerdisp1
	move.b d0, ir
	bmi.s bbaadd4
	bsr gtisz
	beq.s postindex1
	bset #7, ir
postindex1:
	bsr getsc
	move.b d0, sc
	bset #15, d6
outerdisp:
	move.b (a6)+, d0
	cmp.b #0x29, d0
	beq.s encdea
	cmp.b #0x2c, d0
	bne.s bbaadd4
outerdisp1:
	tst.l d6
	bmi.s bbaadd4
	bsr expr
	move.l d0, od
	bset #31, d6
	cmp.b #0x29, (a6)+
	bne.s bbaadd4
encdea:
	tst.l d6
	bmi.s encdea0
	clr.l od
encdea0:
	tst.w d6
	bmi.s encdea0a
	clr.b ir
	clr.b sc
encdea0a:
	tst.b d6
	bmi.s encdea0b
	move.b #8, br
encdea0b:
	btst #29, d6
	bne.s encdea0c
	clr.l bd
encdea0c:
	tst.b d6
	bpl encdea1
	btst #30, d6
	bne encdea1
	tst.w d6
	bmi.s encdea2
	move.w od+2, d0
	ext.l d0
	cmp.l od, d0
	bne.s encdea8
	move.w d0, ea1
	moveq #1, d1
	move.b br, d0
	bpl.s encdea3
	moveq #0x3a, d0
	rts
encdea3:
	tst.w ea1
	beq.s encdea4
	add.b #0x20, d0
	rts
encdea4:
	moveq #0, d1
	addq.b #8, d0
	rts
encdea2:
	move.b od+3, d0
	ext.w d0
	ext.l d0
	cmp.l od, d0
	bne.s encdea8
	move.b d0, ea1+1
	move.b ir, d0
	rol.b #4, d0
	move.b sc, d1
	add.b d1, d1
	add.b d1, d0
	move.b d0, ea1
	moveq #1, d1
	move.b br, d0
	bpl.s encdea5
	moveq #0x3b, d0
	rts
encdea5:
	add.b #0x28, d0
	rts
encdea8:
	cmp.b #2, proc
	bcs.s range
	move.l od, bd
	clr.l od
	bclr #31, d6
	bset #29, d6
	bra.s encdea9
range:
	trap #err
	dc.b 0
.ascii  "Out of range"
	dc.b  0
.align 2
encdea1:
	bsr chk68020
encdea9:
	move.b ir, d0
	rol.b #4, d0
	move.b sc, d1
	add.b d1, d1
	addq.b #1, d1
	add.b d1, d0
	move.b d0, ea1
	moveq #1, d1
	moveq #0, d0
	tst.b d6
	bmi.s encdea1a
	bset #7, d0
encdea1a:
	tst.w d6
	bmi.s encdea1b
	bset #6, d0
encdea1b:
	move.l bd, d2
	lea ea2, a0
	bsr.s calcsz
	asl.b #4, d3
	or.b d3, d0
	btst #30, d6
	beq.s encdea6
	tst.w d6
	bpl.s encdea1c
	btst #28, d6
	bne.s encdea1c
	bset #2, d0
encdea1c:
	move.l od, d2
	bsr.s calcsz
	or.b d3, d0
encdea6:
	move.b d0, ea1+1
	move.b br, d0
	bmi.s encdea7
	add.b #0x28, d0
	rts
encdea7:
	moveq #0x3b, d0
	rts
calcsz:
	move.l d2, d3
	beq.s calcsz0
	ext.l d3
	cmp.l d2, d3
	bne.s calcsz1
	move.w d2, (a0)+
	addq.w #1, d1
	moveq #2, d3
	rts
calcsz1:
	move.l d2, (a0)+
	addq.w #2, d1
	moveq #3, d3
	rts
calcsz0:
	moveq #1, d3
	rts
nperr:
	trap #err
	dc.b 0
.ascii  "Invalid number of passes required"
	dc.b  0
	dc.b  0
.align 2
START:
asm:
	movem.l a5/a6, -(a7)
	lea basvar, a0
	moveq #51, d0
asm1:
	clr.l (a0)+
	dbra d0, asm1
	move.l top, a0
	move.l a0, basvrtp
	move.l a0, vartop
	lea lbla, a0
	moveq #25, d0
asm2:
	clr.l (a0)+
	dbra d0, asm2
	move.l npasses, d0
	subq.l #1, d0
	cmp.l #3, d0
	bhi.s nperr
	move.b d0, pass
stpass:
	move.l dest, a0
	move.l a0, loc
	move.l a0, objad
	clr.b proc
	clr.b endflg
	move.l page, a6
stline:
	move.w (a6)+, d0
	beq.s endpass
	pea -2(a6, d0.w)
	move.w (a6)+, cline
inst:
	move.l a6, stinst
	tst.b esc
	bmi.s escape
	bsr.s nospc
	cmp.b #0x5c, d0
	beq.s comment
	clr.l locinc
	bsr asminst
	bsr wrtobj
	tst.b endflg
	bmi.s endpass1
	bsr.s nospc
	cmp.b #58, d0
	beq.s inst
	cmp.b #13, d0
	bne syntax
endline:
	move.l (a7)+, a6
	bra.s stline
endpass1:
	addq.l #4, a7
endpass:
	subq.b #1, pass
	bcc.s stpass
	movem.l (a7)+, a5/a6
	rts
comment:
	cmp.b #13, (a6)+
	bne.s comment
	subq.l #1, a6
	moveq #0, d7
	bsr wrtobj
	bra.s endline
nospc:
	move.b (a6)+, d0
	cmp.b #32, d0
	beq.s nospc
	rts
ns2:
	move.b (a6)+, d0
	cmp.b #32, d0
	beq.s ns2
	subq.l #1, a6
	rts
escape:
	trap #err
	dc.b 17
.ascii  "Escape"
	dc.b  0
.align 2
align:
	btst #0, loc+3
	beq.s align0
	addq.l #1, loc
	tst.l lblad
	beq.s align1
	move.l lblad, a0
	addq.l #1, (a0)
align1:
	tst.b pass
	bne.s align0
	move.l objad, a0
	clr.b (a0)+
	move.l a0, objad
align0:
	rts
asminst0:
	subq.l #1, a6
	rts
asminst:
	clr.l lblad
	cmp.b #46, d0
	beq deflabel
asminst1:
	moveq #0, d7
	cmp.b #13, d0
	beq.s asminst0
	cmp.b #58, d0
	beq.s asminst0
	and.b #0xdf, d0
	sub.b #0x41, d0
	bcs.s bbaadd0b
	cmp.b #25, d0
	bhi.s bbaadd0b
	ext.w d0
	lea ot-.-2(pc), a0
	moveq #0, d2
	move.b 0(a0, d0.w), d2
	add.w d0, d0
	lea mt-.-2(pc), a0
	add.w 0(a0, d0.w), a0
	bsr match
	bcc.s directive
	bsr.s align
	add.w d0, d2
	lea gt-.-2(pc), a0
	lea pgt-.-2(pc), a1
	moveq #0, d0
	move.b 0(a1, d2.w), d0
	moveq #0, d1
	move.b 0(a0, d2.w), d1
	move.w d1, d2
	and.w #63, d1
	add.w d1, d1
	lsr.w #6, d2
	cmp.b proc, d2
	bhi procerr
	lea gpjt-.-2(pc), a0
	add.w 0(a0, d1.w), a0
	lea objbuf, a4
	moveq #1, d7
	jmp (a0)
bbaadd0b:
	bra bbaadd
directive:
	subq.l #1, a6
	lea dtab-.-2(pc), a0
	bsr match
	bcc.s bbaadd0b
	add.w d0, d0
	lea djt-.-2(pc), a0
	add.w 0(a0, d0.w), a0
	moveq #0, d7
	jmp (a0)
redeferr:
	trap #err
	dc.b 0
.ascii  "Redefined label"
	dc.b  0
	dc.b  0
.align 2
deflabel:
	bsr fndv0
	bcc.s defl0
	move.w (a2), d0
	cmp.b pass, d0
	beq.s redeferr
	move.b pass, 1(a2)
	move.l a1, a6
	bra.s defl1
defl0:
	move.l a6, a1
defl2:
	move.b (a6)+, d0
	cmp.b #48, d0
	bcs.s defl3
	cmp.b #57, d0
	bls.s defl2
	cmp.b #64, d0
	bls.s defl3
	and.b #0xdf, d0
	cmp.b #90, d0
	bls.s defl2
defl3:
	subq.l #1, a6
	move.l a6, d0
	sub.l a1, d0
	add.w #12, d0
	and.w #0xfffe, d0
	move.l vartop, a2
	lea 0(a2, d0.w), a3
	cmp.l himem, a3
	bcc.s noroom
	move.l a3, vartop
	move.l a2, (a0)
	clr.l (a2)+
	bra.s defl5
defl4:
	move.b (a1)+, d0
	cmp.b #0x40, d0
	bls.s defl4a
	and.b #0xdf, d0
defl4a:
	move.b d0, (a2)+
defl5:
	cmp.l a6, a1
	bcs.s defl4
	clr.b (a2)+
	move.l a2, d0
	addq.l #1, d0
	and.w #0xfffe, d0
	move.l d0, a2
defl1:
	moveq #0, d0
	move.b pass, d0
	move.w d0, (a2)+
	move.l a2, -(a7)
	bsr ns2
	cmp.b #61, d0
	bne.s defl6
	addq.l #1, a6
	bsr exp1
	bra.s defl7
defl6:
	move.l loc, d0
	move.l (a7), lblad
defl7:
	move.l (a7)+, a2
	move.l d0, (a2)
	bsr nospc
	bra asminst1
noroom:
	trap #err
	dc.b 0
.ascii  "No room"
	dc.b  0
	dc.b  0
.align 2
gpjt:
	dc.w g0-gpjt, g1-gpjt, g2-gpjt, g3-gpjt, g4-gpjt, g5-gpjt, g6-gpjt
	dc.w g7-gpjt, g8-gpjt, g9-gpjt, g10-gpjt, g11-gpjt, g12-gpjt, g13-gpjt
	dc.w g14-gpjt, g15-gpjt, g16-gpjt, g17-gpjt, g18-gpjt, g19-gpjt
	dc.w g20-gpjt, g21-gpjt, g22-gpjt, g23-gpjt, g24-gpjt, g25-gpjt, g26-gpjt
	dc.w g27-gpjt, g28-gpjt, g29-gpjt, g30-gpjt, g31-gpjt, g32-gpjt, g33-gpjt
	dc.w g34-gpjt, g35-gpjt, g36-gpjt
dtab:
.ascii "OR"
	dc.b  0xc7
.ascii  "D"
	dc.b  0xc3
.ascii  "D"
	dc.b  0xd3
.ascii  "PRO"
	dc.b  0xc3
.ascii  "EN"
	dc.b  0xc4
	dc.b  0
.align 2
djt:
	dc.w org-djt, dirdc-djt, dirds-djt, procd-djt, endd-djt
org:
	bsr expr
	move.l d0, loc
	rts
procd:
	bsr expr
	cmp.l #2, d0
	bhi.s bbaaddproc
	move.b d0, proc
	rts
bbaaddproc:
	trap #err
	dc.b 0
.ascii  "Invalid processor code"
	dc.b  0
.align 2
wrtobj:
	tst.b pass
	bne updloc
	tst.l lstflg
	beq.s wrtobj0
	lea objbuf, a4
	move.l loc, d1
	moveq #9, d0
	trap #gen
	trap #msg
	dc.b 58
	dc.b  32
	dc.b  0
	dc.b  0
.align 2
	move.w d7, d2
	beq.s wrtobj1
	move.w (a4)+, d1
	moveq #8, d0
	trap #gen
	subq.w #1, d2
	moveq #32, d0
	trap #wrch
	bra.s wrtobj2
wrtobj1:
	trap #msg
	dc.b 32
	dc.b  32
	dc.b  32
	dc.b  32
	dc.b  32
	dc.b  0
.align 2
wrtobj2:
	move.l stinst, a0
wrtobj6:
	cmp.b #32, (a0)+
	beq.s wrtobj6
	subq.l #1, a0
	bsr.s wrtlbl
wrtobj3:
	move.b (a0)+, d0
	trap #wrch
	cmp.l a6, a0
	bcs.s wrtobj3
	bra.s wrtobj5
wrtobj4:
	bsr.s out10sp
	move.w (a4)+, d1
	moveq #8, d0
	trap #gen
	moveq #32, d0
	trap #wrch
wrtobj5:
	trap #newl
	dbra d2, wrtobj4
wrtobj0:
	move.w d7, d2
	subq.w #1, d2
	bcs.s updloc
	lea objbuf, a4
	move.l objad, a3
wrtobj0a:
	move.w (a4)+, (a3)+
	dbra d2, wrtobj0a
	move.l a3, objad
updloc:
	move.w d7, d2
	add.w d2, d2
	ext.l d2
	add.l locinc, d2
	add.l d2, loc
	rts
wrtlbl0:
	trap #msg
	dc.b 32
	dc.b  32
	dc.b  0
	dc.b  0
.align 2
out10sp:
	trap #msg
	dc.b 32
	dc.b  32
	dc.b  32
	dc.b  32
	dc.b  32
	dc.b  32
	dc.b  32
	dc.b  32
	dc.b  32
	dc.b  32
	dc.b  0
	dc.b  0
.align 2
	rts
wrtlbl:
	cmp.b #46, (a0)
	bne.s wrtlbl0
	addq.l #1, a0
	moveq #10, d1
wrtlbl1:
	move.b (a0)+, d0
	cmp.b #48, d0
	bcs.s wrtlbl2
	cmp.b #57, d0
	bls.s wrtlbl3
	cmp.b #65, d0
	bcs.s wrtlbl2
	and.b #0xdf, d0
	cmp.b #90, d0
	bhi.s wrtlbl2
wrtlbl3:
	move.b -1(a0), d0
	trap #wrch
	subq.w #1, d1
	bra.s wrtlbl1
wrtlbl5:
	cmp.b #32, -(a0)
	beq.s wrtlbl4
	moveq #32, d0
	trap #wrch
wrtlbl4:
	rts
wrtlbl2:
	tst.w d1
	bmi.s wrtlbl5
wrtlbl6:
	moveq #32, d0
	trap #wrch
	dbra d1, wrtlbl6
	bra.s wrtlbl5
g0t:
	dc.w 0x4e71, 0x4afc, 0x4e70, 0x4e73, 0x4e77, 0x4e75, 0x4e76
g0:
	lea g0t-.-2(pc), a0
	add.w d0, d0
	move.w 0(a0, d0.w), (a4)
	rts
immed:
	move.l d1, -(a7)
	bsr nospc
	cmp.b #0x23, d0
	bne.s bbaadd5
	bsr expr
	move.l (a7)+, d1
	rts
bbaadd5:
	bra bbaadd
g1:
	move.w d0, d6
	bsr.s immed
	subq.w #1, d6
	bhi.s g1a
	beq.s g1b
	cmp.l #7, d0
	bhi.s bbaadd5
	or.w #0x4848, d0
	move.w d0, (a4)
	rts
g1b:
	cmp.l #15, d0
	bhi.s bbaadd5
	or.w #0x4e40, d0
	move.w d0, (a4)
	rts
g1a:
	subq.w #1, d6
	bne.s g1c
	move.l d0, d1
	ext.l d0
	cmp.l d0, d1
	bne.s bbaadd5
	move.w #0x4e74, (a4)+
	move.w d0, (a4)
	moveq #2, d7
	rts
g1c:
	swap d0
	tst.w d0
	bne.s bbaadd5
	move.w #0x4e72, d0
	swap d0
	move.l d0, (a4)
	moveq #2, d7
	rts
g3:
	subq.w #1, d0
	blt.s exg
	bne.s g3a
	bsr gtisz
	moveq #4, d6
	and.w d0, d6
	asl.w #4, d6
	or.w #0x4880, d6
	bsr datreg
	or.w d0, d6
	move.w d6, (a4)
	rts
g3a:
	subq.w #1, d0
	bne.s g3b
	moveq #4, d0
	bsr gtsz1
	cmp.b #4, d0
	bne.s bbaadd0c
	bsr datreg
	or.w #0x49c0, d0
	move.w d0, (a4)
	rts
g3b:
	subq.w #2, d0
	bgt.s g3d
	beq.s g3c
	bsr genreg
	or.w #0x06c0, d0
	move.w d0, (a4)
	rts
g3c:
	bsr datreg
	or.w #0x4840, d0
	move.w d0, (a4)
	rts
g3d:
	bsr adreg
	or.w #0x4e58, d0
	move.w d0, (a4)
	rts
exg:
	moveq #4, d0
	bsr gtsz1
	cmp.b #4, d0
bbaadd0c:
	bne bbaadd
	bsr genreg
	move.w d0, d6
	bsr cm
	bsr genreg
	cmp.b #7, d0
	bhi.s exg1
	exg d6, d0
exg1:
	move.w d0, d1
	eor.w d6, d1
	and.w #7, d6
	add.w d6, d6
	asl.w #8, d6
	or.w d6, d0
	or.w #0xc140, d0
	btst #3, d1
	beq.s exg2
	eor.w #0xc0, d0
exg2:
	move.w d0, (a4)
	rts
g2:
	asl.w #8, d0
	or.w #0x5000, d0
	move.w d0, d6
	bsr gtsz
	tst.b d0
	bne.s g2a
	or.w #0xfc, d6
	move.w d6, (a4)
	rts
g2a:
	subq.b #2, d0
	blt.s bbaadd0c
	bne.s g2l
	bsr immed
	or.w #0xfa, d6
	move.w d6, (a4)+
	move.w d0, (a4)+
	moveq #2, d7
	rts
g2l:
	bsr immed
	or.w #0xfb, d6
	move.w d6, (a4)+
	move.l d0, (a4)+
	moveq #3, d7
	rts
dirdc:
	bsr gtsz0
	tst.b d0
	bmi szinv
	subq.b #2, d0
	move.b d0, d7
	bmi.s dirdc1
	bsr align
dirdc1:
	bsr ns2
	cmp.b #0x22, d0
	bne.s dirdc2
	tst.b d7
	bpl.s dirdc2
dirdc3:
	addq.l #1, a6
	move.b (a6), d0
	cmp.b #34, d0
	beq.s dirdc4
	cmp.b #13, d0
	beq msngquot
dirdc6:
	addq.l #1, locinc
	tst.b pass
	bne.s dirdc5
	move.l objad, a0
	move.b d0, (a0)+
	move.l a0, objad
dirdc5:
	bra.s dirdc3
dirdc4:
	addq.l #1, a6
	move.b (a6), d0
	cmp.b #34, d0
	beq.s dirdc6
	bra.s dirdc7
dirdc2:
	bsr expr
	moveq #0, d1
	move.b d7, d1
	addq.b #2, d1
	add.l d1, locinc
	tst.b pass
	bne.s dirdc7
	move.l objad, a0
	tst.b d7
	beq.s dirdcw
	bpl.s dirdcl
	move.b d0, (a0)+
	bra.s dirdc8
dirdcw:
	move.w d0, (a0)+
	bra.s dirdc8
dirdcl:
	move.l d0, (a0)+
dirdc8:
	move.l a0, objad
dirdc7:
	bsr nospc
	cmp.b #44, d0
	beq.s dirdc1
	subq.l #1, a6
	moveq #0, d7
	rts
dirds:
	bsr gtsz0
	tst.b d0
	bmi szinv
	lsr.b #1, d0
	move.b d0, d7
	bsr expr
	asl.l d7, d0
	move.l d0, locinc
	moveq #0, d7
	rts
endd:
	st endflg
	moveq #0, d7
	rts
	rts
mdtab:
	dc.b 10
	dc.b  10
	dc.b  10
	dc.b  10
	dc.b  10
	dc.b  10
	dc.b  10
	dc.b  10
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b  2
	dc.b 15
	dc.b  15
	dc.b  15
	dc.b  15
	dc.b  15
	dc.b  15
	dc.b  15
	dc.b  15
	dc.b  14
	dc.b  14
	dc.b  14
	dc.b  14
	dc.b  14
	dc.b  14
	dc.b  14
	dc.b  14
	dc.b 14
	dc.b  14
	dc.b  14
	dc.b  14
	dc.b  14
	dc.b  14
	dc.b  14
	dc.b  14
	dc.b  15
	dc.b  15
	dc.b  15
	dc.b  15
	dc.b  15
	dc.b  15
	dc.b  15
	dc.b  15
	dc.b 15
	dc.b  15
	dc.b  15
	dc.b  15
	dc.b  15
	dc.b  15
	dc.b  15
	dc.b  15
	dc.b  15
	dc.b  15
	dc.b  13
	dc.b  13
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  0
.align 2
bbaadd6:
	bra bbaadd
chkmd:
	ext.w d0
	move.w d0, -(a7)
	bsr getea
	cmp.b #0x3c, d0
	bcc.s chkmd1
	lea mdtab-.-2(pc), a0
	moveq #15, d3
	and.w (a7)+, d3
	move.w d3, d2
	and.w #0xff, d0
	and.b 0(a0, d0.w), d2
	cmp.b d3, d2
	bne.s bbaadd6
	rts
chkmd1:
	bhi.s chkmd2
	moveq #16, d2
	and.w (a7)+, d2
	beq.s bbaadd6
	rts
chkmd2:
	cmp.b #192, d0
	bcs.s bbaadd6
	cmp.b #193, d0
	bhi.s bbaadd6
	moveq #32, d2
	and.w (a7)+, d2
	beq.s bbaadd6
	rts
g36:
	asl.w #8, d0
	add.w #0x50c0, d0
	move.w d0, -(a7)
	move.w #0xa1e, -(a7)
	move.l a7, a0
	bsr.s g4a
	addq.l #4, a7
	rts
g4t:
	dc.l 0xa284200, 0x10f4ec0, 0x10f4e80, 0x10f4840, 0xa1e4800
	dc.l 0xa284400, 0xa284600, 0xa284000, 0xa1e4ac0, 0x8284a00
g4:
	asl.w #2, d0
	lea g4t-.-2(pc, d0.w), a0
g4a:
	move.w 2(a0), (a4)
	move.b 1(a0), d0
	lsr.b #4, d0
	bsr gtsz1
	moveq #-16, d1
	or.b 1(a0), d1
	and.b d0, d1
	bne bbaadd
	bsr.s addsz
	move.b (a0), d0
	bsr chkmd
tfrx0:
	or.w d0, (a4)+
tfrext:
	add.w d1, d7
	lea ea1, a0
	bra.s tfrx2
tfrx1:
	move.w (a0)+, (a4)+
tfrx2:
	dbra d1, tfrx1
	rts
addsz:
	cmp.b #2, d0
	bcs.s addsz0
	beq.s addsz1
	or.w #0xc0, (a4)
addsz1:
	eor.w #0x40, (a4)
addsz0:
	rts
g5t:
	dc.w 0xe100, 0xe000, 0xe108, 0xe008, 0xe118, 0xe018, 0xe110, 0xe010
	dc.w 0xe1c0, 0xe0c0, 0xe3c0, 0xe2c0, 0xe7c0, 0xe6c0, 0xe5c0, 0xe4c0
g5:
	add.w d0, d0
	pea g5t-.-2(pc, d0.w)
	bsr gtsz0
	clr.w (a4)
	bsr.s addsz
	moveq #0x1a, d0
	bsr chkmd
	cmp.b #0x3c, d0
	beq.s g5i
	cmp.b #7, d0
	bls.s g5v
	cmp.w #0x40, (a4)
	bne.s bbaadd7
	or.w d0, (a4)
	move.l (a7)+, a0
	move.w 16(a0), d2
	or.w d2, (a4)+
	bra.s tfrext
g5i:
	move.l ea1, d0
	beq.s bbaadd7
	cmp.l #8, d0
	bhi.s bbaadd7
	and.w #7, d0
	add.w d0, d0
	asl.w #8, d0
	or.w d0, (a4)
	bsr cm
g5a:
	bsr datreg
	or.w (a4), d0
	move.l (a7)+, a0
	or.w (a0), d0
	move.w d0, (a4)
	rts
g5v:
	add.w d0, d0
	asl.w #8, d0
	or.w #0x20, d0
	or.w d0, (a4)
	cmp.b #44, (a6)+
	beq.s g5a
bbaadd7:
	bra bbaadd
g6t:
	dc.w 0xc100, 0x8100, 0xd100, 0x9100, 0x01fe, 0x01fe, 0x02f8, 0x02f8
g6:
	add.w d0, d0
	lea g6t-.-2(pc), a0
	move.w 0(a0, d0.w), (a4)
	move.b 9(a0, d0.w), d1
	move.b 8(a0, d0.w), d0
	bsr gtsz1
	and.b d0, d1
	bne.s bbaadd7
	bsr addsz
g6b:
	bsr reg
	bcc.s g6m
	cmp.b #7, d0
	bhi.s bbaadd7
	or.w d0, (a4)
	bsr cm
	bsr datreg
g6a:
	add.w d0, d0
	asl.w #8, d0
	or.w d0, (a4)
	rts
g6m:
	bsr getea
	sub.b #32, d0
	bcs.s bbaadd8
	cmp.b #7, d0
	bhi.s bbaadd8
	addq.b #8, d0
	ext.w d0
	or.w d0, (a4)
	bsr cm
	bsr getea
	ext.w d0
	sub.b #32, d0
	bcs.s bbaadd8
	cmp.b #7, d0
	bls.s g6a
bbaadd8:
	bra bbaadd
g7:
	ror.w #2, d0
	or.w #0x9000, d0
	move.w d0, (a4)
	bsr gtsz0
	moveq #0x10, d2
	cmp.b #1, d0
	bne.s g7a
	moveq #0x18, d2
g7a:
	bsr addsz
	move.w d2, d0
	bsr chkmd
	bsr cm
	cmp.b #0x3c, d0
	beq.s g7i
	cmp.b #7, d0
	bls.s g7ds
g7rd1:
	or.w d0, (a4)
	bsr genreg
g7rd:
	cmp.b #7, d0
	bls.s g7dd
g7ad:
	move.w (a4), d2
	and.b #0xc0, d2
	beq.s bbaadd8
	bpl.s g7ad1
	or.w #0x100, (a4)
g7ad1:
	or.w #0xc0, (a4)
	subq.w #8, d0
g7dd:
	add.w d0, d0
	asl.w #8, d0
	bra tfrx0
g7ds:
	move.w d0, -(a7)
	moveq #2, d0
	bsr chkmd
	cmp.b #15, d0
	bhi.s g7ds2
	move.w (a7)+, d2
	or.w d2, (a4)
	bra.s g7rd
g7ds2:
	or.w #0x100, d0
	move.w (a7)+, d2
	add.w d2, d2
	asl.w #8, d2
	or.w d2, d0
	bra tfrx0
g7i:
	move.l ea1, -(a7)
	moveq #2, d0
	bsr chkmd
	cmp.b #8, d0
	bcs.s g7i2
	cmp.b #15, d0
	bhi.s g7i2
g7ia:
	subq.w #8, d0
	add.w d0, d0
	asl.w #8, d0
	or.w d0, (a4)
	move.w (a4), d2
	and.b #0xc0, d2
	beq bbaadd
	bpl.s g7ad3
	or.w #0x1fc, (a4)+
	move.l (a7)+, (a4)
	moveq #3, d7
	rts
g7ad3:
	or.w #0xfc, (a4)+
	addq.w #2, a7
	move.w (a7)+, (a4)
	moveq #2, d7
	rts
g7i2:
	moveq #4, d3
g7i3:
	move.b (a4), d2
	and.b #0x40, d2
	lsr.b #5, d2
	or.b d3, d2
g7i4:
	move.b d2, (a4)
	or.w d0, (a4)
	move.l (a7)+, d0
	bsr.s outimd
	bra tfrext
outimd:
	move.w (a4)+, d2
	and.b #0xc0, d2
	bmi.s outimdl
	bne.s outimdw
	and.w #0xff, d0
outimdw:
	move.w d0, (a4)+
	addq.w #1, d7
	rts
outimdl:
	move.l d0, (a4)+
	addq.w #2, d7
	rts
g8:
	bsr gtsz0
	move.w #0xb000, (a4)
	moveq #0x10, d2
	cmp.b #1, d0
	bne.s g8a
	moveq #0x18, d2
g8a:
	bsr addsz
	move.w d2, d0
	bsr chkmd
	bsr cm
	cmp.b #0x3c, d0
	beq.s g8i
	bra g7rd1
g8i:
	move.l ea1, -(a7)
	moveq #2, d0
	bsr chkmd
	cmp.b #8, d0
	bcs.s g8i2
	cmp.b #15, d0
	bls g7ia
g8i2:
	moveq #12, d2
	bra.s g7i4
g9:
	bsr gtsz0
	move.w #0xb100, (a4)
	bsr addsz
	moveq #0x18, d0
	bsr chkmd
	bsr cm
	cmp.b #0x3c, d0
	beq.s g9i
	cmp.b #7, d0
	bhi.s bbaadd9
	add.w d0, d0
	asl.w #8, d0
	or.w d0, (a4)
	moveq #10, d0
	bsr chkmd
	bra tfrx0
bbaadd9:
	bra bbaadd
g9i:
	moveq #10, d7
g9i0:
	move.l ea1, -(a7)
	moveq #0x2a, d0
	bsr chkmd
	tst.b d0
	bpl.s g9i2
	lsr.b #1, d0
	bcc.s g9sr
	tst.b 1(a4)
	bne.s bbaadd9
	bra.s g9sr2
g9sr:
	cmp.b #0x40, 1(a4)
	bne.s bbaadd9
g9sr2:
	moveq #0x3c, d0
g9i2:
	or.w d0, (a4)
	move.w d7, d2
	moveq #1, d7
	bra g7i4
g10:
	ror.w #2, d0
	or.w #0x8000, d0
	move.w d0, (a4)
	bsr gtsz0
	bsr addsz
	moveq #0x18, d0
	bsr chkmd
	bsr cm
	cmp.b #0x3c, d0
	beq.s g10i
	cmp.b #7, d0
	bls.s g10ds
g10dd:
	or.w d0, (a4)
	bsr datreg
	bra g7dd
g10ds:
	move.w d0, -(a7)
	moveq #10, d0
	bsr chkmd
	cmp.b #7, d0
	bhi.s g10ds2
	add.w d0, d0
	asl.w #8, d0
	or.w (a7)+, d0
	or.w d0, (a4)
	rts
g10ds2:
	or.w d0, (a4)
	move.w (a7)+, d0
	or.w #0x100, (a4)
	bra g7dd
g10i:
	moveq #0x40, d0
	and.b (a4), d0
	lsr.b #5, d0
	move.b d0, d7
	bra g9i0
g11:
	addq.w #1, d0
	asl.w #8, d0
	or.w #0x50c8, d0
	move.w d0, (a4)
	bsr datreg
	or.w d0, (a4)+
	bsr cm
	bsr exp1
	sub.l loc, d0
	subq.l #2, d0
	move.l d0, d1
	ext.l d0
	cmp.l d0, d1
	bne range
	move.w d0, (a4)
	moveq #2, d7
	rts
g34:
	asl.w #8, d0
	or.w #0x6000, d0
	move.w d0, (a4)
	bsr gtsz0
	cmp.b #1, d0
	beq bbaadd
	move.b d0, d6
	bsr exp1
	sub.l loc, d0
	subq.l #2, d0
	cmp.b #2, d6
	beq.s g34w
	bgt.s g34l
	move.l d0, d1
	ext.w d0
	ext.l d0
	cmp.l d0, d1
	bne range
	move.b d0, 1(a4)
	rts
g34w:
	move.l d0, d1
	ext.l d0
	cmp.l d0, d1
	bne range
	move.w d0, 2(a4)
	moveq #2, d7
	rts
g34l:
	bsr chk68020
	move.l d0, 2(a4)
	st 1(a4)
	moveq #3, d7
	rts
g12:
	moveq #10, d7
	move.w d0, d1
	bne.s g12a
	moveq #8, d7
g12a:
	asl.w #6, d1
	move.w d1, (a4)
	bsr reg
	bcc.s g12i
	cmp.b #7, d0
	bhi bbaadd
	add.b d0, d0
	addq.b #1, d0
	move.b d0, (a4)
	bsr cm
	move.w d7, d0
	bsr chkmd
	moveq #1, d7
	bra tfrx0
g12i:
	bsr immed
	exg d0, d7
	bsr cm
	bsr chkmd
	or.w #0x800, d0
	or.w d0, (a4)+
	moveq #7, d2
	cmp.b d2, d0
	bhi.s g12i2
	moveq #31, d2
g12i2:
	cmp.l d2, d7
	bhi.s bitnumerr
	move.w d7, (a4)+
	moveq #2, d7
	bra tfrext
bitnumerr:
	trap #err
	dc.b 0
.ascii  "Invalid bit number"
	dc.b  0
.align 2
g16:
	or.b #0x50, d0
	move.b d0, (a4)
	clr.b 1(a4)
	bsr gtsz0
	bsr addsz
	bsr immed
	bsr cm
	tst.l d0
	beq.s invim
	cmp.l #8, d0
	bhi.s invim
	and.b #7, d0
	add.w d0, d0
	asl.w #8, d0
	or.w d0, (a4)
	moveq #2, d0
	bsr chkmd
	cmp.b #7, d0
	bls.s g16a
	cmp.b #15, d0
	bhi.s g16a
	tst.b 1(a4)
	beq bbaadd
g16a:
	bra tfrx0
invim:
	trap #err
	dc.b 0
.ascii  "Invalid immediate data value"
	dc.b  0
.align 2
g17:
	bsr immed
	move.b d0, 1(a4)
	bsr cm
	bsr datreg
	add.w d0, d0
	or.w #0x70, d0
	move.b d0, (a4)
	rts
g18:
	move.w d0, d7
	clr.w (a4)
	bsr gtsz0
	bsr addsz
	asl (a4)
	asl (a4)
	asl (a4)
	moveq #1, d0
	bsr chkmd
	or.w #0xc0, d0
	or.w d0, (a4)+
	bsr cm
	bsr genreg
	add.w d0, d0
	add.w d7, d0
	asl.w #3, d0
	move.b d0, (a4)+
	clr.b (a4)+
	moveq #2, d7
	bra tfrext
g19:
	bsr gtisz
	and.w #2, d0
	bne.s g19a
	bsr chk68020
g19a:
	asl.w #6, d0
	move.b d0, 1(a4)
	clr.b (a4)
	moveq #8, d0
	bsr chkmd
	or.w d0, (a4)
	bsr cm
	bsr datreg
	add.w d0, d0
	asl.w #8, d0
	or.w d0, (a4)
	or.w #0x4100, (a4)+
	bra tfrext
g20:
	bsr immed
	cmp.l #255, d0
	bhi invim
	move.w d0, 2(a4)
	bsr cm
	moveq #1, d0
	bsr chkmd
	or.w #0x06c0, d0
	move.w d0, (a4)+
	addq.w #2, a4
	moveq #2, d7
	bra tfrext
g21:
	move.w #0x118, (a4)
	bsr gtsz0
	bsr addsz
	asl (a4)
	asl (a4)
	asl (a4)
	addq.b #2, (a4)
	bsr datreg
	move.w d0, d7
	bsr cm
	bsr datreg
	asl.w #6, d0
	or.w d7, d0
	move.w d0, 2(a4)
	bsr cm
	moveq #6, d0
	bsr chkmd
	or.w d0, (a4)
	addq.l #4, a4
	moveq #2, d7
	bra tfrext
g22:
	bsr gtisz
	and.w #4, d0
	asl.w #7, d0
	or.w #0x0cfc, d0
	move.w d0, (a4)+
	bsr datreg
	cmp.b #58, (a6)+
	bne.s bbaadd10
	move.w d0, (a4)
	bsr datreg
	bsr cm
	move.w d0, 2(a4)
	bsr datreg
	cmp.b #58, (a6)+
	bne.s bbaadd10
	asl.w #6, d0
	or.w d0, (a4)
	bsr datreg
	bsr cm
	asl.w #6, d0
	or.w d0, 2(a4)
	cmp.b #40, (a6)+
	bne.s bbaadd10
	bsr genreg
	asl.w #4, d0
	or.b d0, (a4)
	cmp.b #41, (a6)+
	bne.s bbaadd10
	cmp.b #58, (a6)+
	bne.s bbaadd10
	cmp.b #40, (a6)+
	bne.s bbaadd10
	bsr genreg
	asl.w #4, d0
	or.b d0, 2(a4)
	cmp.b #41, (a6)+
	bne.s bbaadd10
	moveq #3, d7
	rts
bbaadd10:
	bra bbaadd
g23:
	move.w #0xb108, (a4)
	bsr gtsz0
	bsr addsz
	bsr getea
	sub.b #0x18, d0
	bcs.s bbaadd10
	cmp.b #7, d0
	bhi.s bbaadd10
	or.b d0, 1(a4)
	bsr cm
	bsr getea
	sub.b #0x18, d0
	bcs.s bbaadd10
	cmp.b #7, d0
	bhi.s bbaadd10
	add.w d0, d0
	asl.w #8, d0
	or.w d0, (a4)
	rts
g24:
	moveq #1, d0
	bsr chkmd
	or.w #0x41c0, d0
	move.w d0, (a4)
	bsr cm
	bsr adreg
	subq.w #8, d0
	add.b d0, d0
	or.b d0, (a4)
	addq.l #2, a4
	bra tfrext
g25:
	move.w #0x0e00, (a4)
	bsr gtsz0
	bsr addsz
	moveq #2, d0
	bsr chkmd
	bsr cm
	cmp.b #15, d0
	bls.s g25w
	or.w d0, (a4)+
	bsr genreg
	asl.w #4, d0
	move.b d0, (a4)+
	clr.b (a4)+
	moveq #2, d7
	bra tfrext
g25w:
	asl.w #4, d0
	addq.b #8, d0
	move.b d0, 2(a4)
	clr.b 3(a4)
	moveq #6, d0
	bsr chkmd
	or.w d0, (a4)
	addq.l #4, a4
	moveq #2, d7
	bra tfrext
g27:
	bsr gtisz
	and.w #4, d0
	asl.w #4, d0
	or.w #0x108, d0
	move.w d0, (a4)
	bsr getea
	cmp.b #7, d0
	bls.s g27w
	sub.b #0x28, d0
	bcs.s bbaadd11
	cmp.b #7, d0
	bhi.s bbaadd11
	or.b d0, 1(a4)
	bsr cm
	bsr datreg
	add.w d0, d0
	or.b d0, (a4)
	addq.l #2, a4
	bra tfrext
g27w:
	add.w d0, d0
	or.b d0, (a4)
	bsr cm
	bsr getea
	sub.b #0x28, d0
	bcs.s bbaadd11
	cmp.b #7, d0
	bhi.s bbaadd11
	or.b #128, d0
	or.b d0, 1(a4)
	addq.l #2, a4
	bra tfrext
bbaadd11:
	bra bbaadd
g28md:
	moveq #0x18, d0
	bsr chkmd
	cmp.b #0x3c, d0
	bne.s g28md1
	tst.w (a4)
	bmi.s g28iw
	moveq #2, d1
	rts
g28iw:
	move.w ea2, ea1
	moveq #1, d1
g28md1:
	rts
g28:
	move.w d0, -(a7)
	bsr gtisz
	cmp.b #4, d0
	beq.s g28l
	move.w #0xc0c0, (a4)
	move.w (a7)+, d0
	or.b d0, (a4)
	bsr.s g28md
	or.w d0, (a4)
	bsr cm
	bsr datreg
	add.w d0, d0
	or.b d0, (a4)
	addq.l #2, a4
	bra tfrext
g28l:
	bsr chk68020
	move.w #0x4c00, (a4)
	bsr.s g28md
	or.w d0, (a4)+
	bsr cm
	bsr.s datreg2
	move.w (a7)+, d2
	asl.w #8, d2
	asl.w #3, d2
	or.w d2, d7
	asl.w #8, d0
	asl.w #4, d0
	or.w d7, d0
	move.w d0, (a4)+
	moveq #2, d7
	bra tfrext
datreg2:
	bsr datreg
	moveq #0, d7
	cmp.b #58, (a6)
	bne.s datreg3
	addq.l #1, a6
	move.w d0, d7
	bsr datreg
	or.w #0x400, d7
datreg3:
	rts
g29:
	move.w d0, -(a7)
	bsr gtisz
	cmp.b #4, d0
	beq.s g29l
	move.w (a7)+, d0
	asl.w #8, d0
	or.w #0x80c0, d0
	move.w d0, (a4)
	bsr g28md
	or.w d0, (a4)
	bsr cm
	bsr datreg
	add.w d0, d0
	or.b d0, (a4)
	addq.l #2, a4
	bra tfrext
g29l:
	bsr chk68020
	move.w #0x4c40, (a4)
	bsr g28md
	or.w d0, (a4)+
	bsr cm
	bsr.s datreg2
	move.w (a7)+, d2
	asl.w #8, d2
	asl.w #3, d2
	or.w d2, d7
	btst #10, d7
	bne.s g29l2
	move.b d0, d7
g29l2:
	asl.w #8, d0
	asl.w #4, d0
	or.w d7, d0
	move.w d0, (a4)+
	moveq #2, d7
	bra tfrext
g30:
	move.w d0, -(a7)
	moveq #4, d0
	bsr gtsz1
	cmp.b #4, d0
	bne bbaadd
	move.w #0x4c40, (a4)
	bsr g28md
	or.w d0, (a4)+
	bsr cm
	bsr datreg
	move.w d0, (a4)
	cmp.b #58, (a6)+
	bne bbaadd
	bsr datreg
	asl.w #4, d0
	or.b d0, (a4)
	move.w (a7)+, d0
	asl.b #3, d0
	or.b d0, (a4)+
	addq.l #1, a4
	moveq #2, d7
	bra tfrext
g31:
	bsr adreg
	subq.w #8, d0
	or.w #0x4e50, d0
	move.w d0, (a4)
	bsr cm
	bsr immed
	move.l d0, d1
	ext.l d1
	cmp.l d0, d1
	bne.s g31l
	addq.w #2, a4
	move.w d0, (a4)+
	moveq #2, d7
	rts
g31l:
	cmp.b #2, proc
	bcs invim
	move.w (a4), d1
	and.w #7, d1
	or.w #0x4808, d1
	move.w d1, (a4)+
	move.l d0, (a4)
	moveq #3, d7
	rts
g32:
	asl.w #6, d0
	add.w #0x8140, d0
	move.w d0, (a4)
	bsr g6b
	bsr cm
	addq.l #2, a4
	bsr immed
	cmp.l #0xffff, d0
	bhi invim
	move.w d0, (a4)
	moveq #2, d7
	rts
g35:
	moveq #4, d0
	bsr gtsz1
	cmp.b #4, d0
	bne.s bbaadd12
	bsr reg
	bcc.s bbaadd12
	cmp.b #15, d0
	bhi.s g35rc
	move.w #0x4e7b, (a4)+
	bsr cm
	asl.w #4, d0
	move.b d0, (a4)
	clr.b 1(a4)
	bsr reg
	bcc.s bbaadd12
	sub.b #240, d0
	bcs.s bbaadd12
	ext.w d0
	add.w d0, d0
	lea g35t-.-2(pc), a0
	move.w 0(a0, d0.w), d0
	or.w d0, (a4)
	moveq #2, d7
	rts
g35rc:
	move.w #0x4e7a, (a4)+
	bsr cm
	sub.b #240, d0
	bcs.s bbaadd12
	ext.w d0
	add.w d0, d0
	lea g35t-.-2(pc), a0
	move.w 0(a0, d0.w), (a4)
	bsr genreg
	asl.w #4, d0
	or.b d0, (a4)
	moveq #2, d7
	rts
bbaadd12:
	bra bbaadd
g35t:
	dc.w 0x800, 0x804, 0x803, 0x801, 0x0, 0x1, 0x2, 0x802
outdec:
	clr.b -(a7)
outdec1:
	and.l #0xffff, d0
	divu #10, d0
	swap d0
	add.b #48, d0
	move.b d0, -(a7)
	swap d0
	tst.w d0
	bne.s outdec1
outdec2:
	move.b (a7)+, d0
	trap #wrch
	tst.b d0
	bne.s outdec2
	rts
warnsr:
	tst.b proc
	beq.s warnsr0
	trap #msg
.ascii "WARNING - MOVE.W SR,<ea> at line "
	dc.b  0
.align 2
	move.w cline, d0
	bsr.s outdec
	trap #newl
warnsr0:
	rts
g33a1:
	cmp.b #0xc0, d0
	bne.s g33a2
	bsr cm
	move.b (a7)+, d0
	beq.s g33a1ok
	cmp.b #2, d0
	bne bbaadd
g33a1ok:
	bsr.s warnsr
	moveq #10, d0
	bsr chkmd
	or.w #0x40c0, d0
	move.w d0, (a4)+
	bra tfrext
g33a2:
	cmp.b #0xc1, d0
	bne.s bbaadd13
	bsr cm
	move.b (a7)+, d0
	beq.s g33a2ok
	cmp.b #2, d0
	bne.s bbaadd13
g33a2ok:
	cmp.b #1, proc
	bcs procerr
	moveq #10, d0
	bsr chkmd
	or.w #0x42c0, d0
	move.w d0, (a4)+
	bra tfrext
bbaadd13:
	bra bbaadd
g33a:
	cmp.b #0xf0, d0
	bne.s g33a1
	bsr cm
	move.b (a7)+, d0
	beq.s g33aok
	cmp.b #4, d0
	bne.s bbaadd13
g33aok:
	bsr adreg
	or.w #0x4e68, d0
	move.w d0, (a4)
	rts
g33:
	bsr gtsz
	move.b d0, -(a7)
	bmi.s bbaadd13
	bsr getea
	cmp.b #0x3c, d0
	bhi.s g33a
	bne.s g33b
	ext.w d0
	move.w d0, (a4)+
	move.l ea1, d0
	cmp.b #4, (a7)
	bne.s g33c
	move.l d0, (a4)+
	moveq #3, d7
	bra.s g33e
g33c:
	cmp.b #1, (a7)
	bne.s g33d
	and.w #0xff, d0
g33d:
	move.w d0, (a4)+
	moveq #2, d7
	bra.s g33e
g33b:
	ext.w d0
	move.w d0, (a4)+
	bsr tfrext
g33e:
	bsr cm
	bsr getea
	cmp.b #0x3c, d0
	bhi.s g33f
	cmp.b #0x3a, d0
	bcc bbaadd
	ext.w d0
	move.w d0, d2
	and.w #7, d2
	asl.w #3, d2
	lsr.w #3, d0
	or.w d0, d2
	asl.w #6, d2
	bsr tfrext
	lea objbuf, a4
	or.w d2, (a4)
	move.b (a7)+, d2
	cmp.b #4, d2
	bne.s g33g
	or.w #0x2000, (a4)
	rts
g33g:
	cmp.b #1, d2
	beq.s g33h
	or.w #0x3000, (a4)
	rts
g33h:
	or.w #0x1000, (a4)
	move.w (a4), d0
	and.b #0x38, d0
	cmp.b #8, d0
	beq.s bbaadd14
	move.w (a4), d0
	and.w #0x1c0, d0
	cmp.w #0x40, d0
	beq.s bbaadd14
	rts
g33f:
	sub.b #192, d0
	bcs.s bbaadd14
	beq.s g33tsr
	cmp.b #1, d0
	bne.s g33f1
	move.b (a7)+, d0
	beq.s g33fok
	cmp.b #2, d0
	bne.s bbaadd14
g33fok:
	or.w #0x44c0, objbuf
	rts
bbaadd14:
	bra bbaadd
g33tsr:
	move.b (a7)+, d0
	beq.s g33tsr1
	cmp.b #2, d0
	bne.s bbaadd14
g33tsr1:
	or.w #0x46c0, objbuf
	rts
g33f1:
	cmp.b #48, d0
	bne.s bbaadd14
	lea objbuf, a4
	move.b (a7)+, d0
	beq.s g33f2
	cmp.b #4, d0
	bne.s bbaadd14
g33f2:
	move.w (a4), d0
	subq.w #8, d0
	bcs.s bbaadd14
	cmp.b #7, d0
	bhi.s bbaadd14
	or.w #0x4e60, d0
	move.w d0, (a4)
	moveq #1, d7
	rts
bbaadd15:
	bra.s bbaadd14
g26:
	bsr gtisz
	and.w #4, d0
	asl.w #4, d0
	or.w #0x4880, d0
	move.w d0, (a4)
	bsr getea
	ext.w d0
	cmp.b #15, d0
	bls.s g26w
	cmp.b #0x3a, d0
	bcc.s bbaadd15
	cmp.b #0x20, d0
	bls.s g26a
	cmp.b #0x28, d0
	bcs.s bbaadd15
g26a:
	bsr cm
	or.w #0x400, d0
	or.w d0, (a4)+
	bsr.s reglist
	move.w d7, (a4)+
	moveq #2, d7
	bra tfrext
g26w:
	moveq #0, d7
	bsr.s reglist2
	bsr cm
	bsr getea
	ext.w d0
	cmp.b #15, d0
	bls.s bbaadd15
	cmp.b #0x3a, d0
	bcc.s bbaadd15
	cmp.b #0x17, d0
	bls.s g26w2
	cmp.b #0x1f, d0
	bls.s bbaadd15
	cmp.b #0x27, d0
	bhi.s g26w2
g26w1:
	moveq #15, d2
	moveq #0, d3
g26w1a:
	add.w d7, d7
	roxr.w #1, d3
	dbra d2, g26w1a
	move.w d3, d7
g26w2:
	or.w d0, (a4)+
	move.w d7, (a4)+
	moveq #2, d7
	bra tfrext
reglist:
	moveq #0, d7
reglist1:
	bsr genreg
reglist2:
	bset d0, d7
	bne.s bbaadd16
	cmp.b #0x2f, (a6)+
	beq.s reglist1
	subq.l #1, a6
	rts
bfmd:
	bsr reg
	bcc.s bfmd1
	cmp.b #7, d0
	bhi.s bbaadd16
	moveq #0, d1
	rts
bfmd1:
	move.w d1, d0
	bra chkmd
bbaadd16:
	bra bbaadd
bfspec:
	cmp.b #0x7b, (a6)+
	bne.s bbaadd16
	bsr reg
	bcc.s bfs1
	move.w #0x800, d7
	asl.w #6, d0
	or.w d0, d7
	bra.s bfs2
bfs1:
	bsr immed
	cmp.l #31, d0
	bhi.s bbaadd16
	asl.w #6, d0
	move.w d0, d7
bfs2:
	cmp.b #58, (a6)+
	bne.s bbaadd16
	bsr reg
	bcc.s bfs3
	or.w d0, d7
	or.w #0x20, d7
	bra.s bfs4
bfs3:
	bsr immed
	tst.l d0
	beq.s bbaadd16
	cmp.l #32, d0
	bhi.s bbaadd16
	and.w #31, d0
	or.w d0, d7
bfs4:
	cmp.b #0x7d, (a6)+
	bne.s bbaadd16
	rts
g13:
	moveq #3, d1
	add.w d0, d0
	bne.s g13a
	moveq #1, d1
g13a:
	asl.w #8, d0
	or.w #0xe8c0, d0
	move.w d0, (a4)
	bsr bfmd
	or.w d0, (a4)+
	bsr.s bfspec
	move.w d7, (a4)+
	moveq #2, d7
	bra tfrext
g14:
	add.w d0, d0
	asl.w #8, d0
	or.w #0xe9c0, d0
	move.w d0, (a4)
	moveq #1, d1
	bsr bfmd
	or.w d0, (a4)+
	bsr bfspec
	move.w d7, (a4)
	bsr cm
	bsr datreg
	asl.w #4, d0
	asl.w #8, d0
	moveq #2, d7
	bra tfrx0
g15:
	bsr datreg
	asl.w #4, d0
	move.b d0, 2(a4)
	clr.b 3(a4)
	bsr cm
	moveq #3, d1
	bsr bfmd
	or.w #0xefc0, d0
	move.w d0, (a4)+
	bsr bfspec
	or.w d7, (a4)+
	moveq #2, d7
	bra tfrext


/* 68000 BBC BASIC Interpreter
 *
 * Copyright (C) 1990,2021 Dennis May
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


/* Global variables used by BASIC */
.equ	page, 0xc0
.equ	top, 0xc4
.equ	himem, 0xc8
.equ	user, 0xcc          /* Initial value for 68000 USP */
.equ	lopt, 0xd0          /* LISTO value */
.equ	lnflg, 0xd1         /* Flag indicating that the memory addresses of some lines referred to
                               by number have been cached */
.equ	erl, 0xd2
.equ	lomem, 0xd4
.equ	vartop, 0xd8        /* Top of RAM area used for variable storage */
.equ	cline, 0xdc         /* Currently executing BASIC line number (0 for console command line) */
.equ	rndv, 0xe0          /* RND random number generator internal state */
.equ	prtct, 0xe4         /* Value returned by COUNT function */
.equ	deflen, 0xe6        /* Default string length assumed when a string array is created */
.equ	datptr, 0xe8        /* Points to DATA item to be read by READ */
.equ	formvar, 0x1000     /* @% variable value */
.equ	frmtmd, 0x1001
.equ	frmtnm, 0x1002
.equ	fldsz, 0x1003
.equ	resint, 0x1004      /* A% to Z% stored at 1004 to 1068 */
.equ	varca, 0x106c       /* 106C points to list of variables starting with A, 1070 with B, etc */
.equ	varsa, 0x10d4       /* 10D4 points to list of variables starting with a, 10D8 with b, etc */
.equ	strbf, 0x1200       /* General working buffer for string manipulation */
.equ	ibuf, 0x1300        /* Program editor line input buffer */

/* TRAP instruction numbers for OS functions */
.equ	err, 0
.equ	wrch, 1
.equ	rdch, 2
.equ	gen, 3
.equ	file, 4
.equ	hex, 5
.equ	asci, 6
.equ	newl, 7
.equ	msg, 8

/* Memory flag set by OS if ESCAPE key pressed */
.equ	esc, 0x35

/* Small host side buffer for some operations */
.equ    HOST_SIDE_BUF, 0x5F0

/* Abbreviations for very commonly used labels */
.equ	il, illegal
.equ	sy, syntax
.equ	ix, intexpr
.equ	fpx, fpexpr

/* Everything in one section, START is the entry point */
    .section .text
    .global START

START:
    bra start_basic


/* Floating point format:
 * Each FP value is stored as 6 bytes.
 * First byte contains sign (bit 7=1 for negative, bit 7=0 for positive)
 * 2nd byte = exponent in excess-128. Exponent of 00 means number is zero; denormals are not supported
 * Bytes 3-6 = mantissa, always normalized so bit 31 = 1.
 * Mantissa is >=0.5, <1.
 * So, for example 00 81 80 00 00 00 represents 1.0
 * Mantissa = 0.5, exponent = 1, value = 0.5 * 2^1 = 1.0
 *
 * When passed in/out of functions, a pair of data registers is usually used.
 * First arg in D0,D1; second arg in D2/D3; result returned in D0/D1.
 * D0 or D2 contains mantissa
 * D1 or D3 bit 15 = sign bit
 * D1.B or D3.B = exponent
 */

/* Floating point subtraction and addition */
fpsub:
	eor.w #0xff00, d3
fpadd:
	tst.b d1
	beq.s fpadd0a
	tst.b d3
	beq.s fpadd0
	moveq #0, d4
	cmp.b d3, d1
	beq.s fpadd1
	bcc.s fpadd2
	exg d1, d3
	exg d0, d2
fpadd2:
	sub.b d1, d3
	neg.b d3
	cmp.b #33, d3
	bhi.s fpadd0
	subq.b #1, d3
	beq.s fpadd1a
	lsr.l d3, d2
	roxr.w #1, d4
fpadd1a:
	lsr.l #1, d2
	roxr.w #1, d4
fpadd1:
	eor.w d1, d3
	bmi.s fpsub1
	add.l d2, d0
	bcc.s fpadd3
	roxr.l #1, d0
	roxr.w #1, d4
	addq.b #1, d1
	bcs.s ovfw
fpadd3:
	tst.w d4
	bpl.s fpadd0
	addq.l #1, d0
	bcc.s fpadd0
	roxr.l #1, d0
	addq.b #1, d1
	bcs.s ovfw
fpadd0:
	rts
ovfw:
	trap #err
	dc.b 20
.ascii  "Overflow"
	dc.b  0
.align 2
fpadd0a:
	move.l d2, d0
	move.l d3, d1
	rts
fpsub1:
	neg.w d4
	subx.l d2, d0
	beq.s fpsub3
	bcc.s fpsub2
	neg.w d4
	negx.l d0
	eor.w #0xff00, d1
fpsub2:
	swap d0
	tst.w d0
	bne.s fpsub4
	sub.b #16, d1
	bls.s fpsub0
	move.w d4, d0
	moveq #0, d4
	swap d0
fpsub4:
	swap d0
	bmi.s fpsub5
	subq.b #1, d1
	move.b d1, d3
fpsub6:
	add.w d4, d4
	addx.l d0, d0
	dbmi d1, fpsub6
	cmp.b d3, d1
	bhi.s fpsub0
	tst.b d1
	beq.s fpsub0
fpsub5:
	tst.w d4
	bpl.s fpsub7
	addq.l #1, d0
	bcc.s fpsub7
	roxr.l #1, d0
	addq.b #1, d1
	bcs ovfw
fpsub7:
	rts
fpsub0:
	clr.b d1
	rts
fpsub3:
	tst.w d4
	beq.s fpsub0
	bset #31, d0
	sub.w #32, d1
	bcs.s fpsub0
	rts

/* Floating point multiplication */
fpmul:
	tst.b d1
	beq.s fpsub0
	tst.b d3
	beq.s fpsub0
	add.b d3, d1
	bcc.s fpmul1
	cmp.b #128, d1
	bls.s fpmul2
	bhi ovfw
fpmul1:
	cmp.b #128, d1
	bls.s fpsub0
fpmul2:
	add.b #128, d1
	clr.b d3
	eor.w d3, d1
	move.l d0, -(a7)
	move.w d0, d3
	mulu d2, d3
	move.w d2, d5
	mulu (a7)+, d5
	swap d2
	swap d0
	mulu d2, d0
	move.w d2, d4
	mulu (a7)+, d4
	add.l d5, d4
	bcc.s fpmul3
	add.l #0x10000, d0
fpmul3:
	swap d3
	add.w d4, d3
	clr.w d4
	swap d4
	addx.l d4, d0
fpmuln:
	bmi.s fpmul4
	add.w d3, d3
	addx.l d0, d0
	subq.b #1, d1
	bne.s fpmul6
	clr.b d1
	rts
fpmul4:
	tst.b d1
	beq ovfw
fpmul6:
	tst.w d3
	bpl.s fpmul5
	addq.l #1, d0
	bcc.s fpmul5
	roxr.l #1, d0
	addq.b #1, d1
	bcs ovfw
fpmul5:
	rts
fpmul0:
	clr.b d1
	rts

/* Floating point division */
divby0:
	trap #err
	dc.b 18
.ascii  "Division by zero"
	dc.b  0
.align 2

fpdiv:
	tst.b d3
	beq.s divby0
	tst.b d1
	beq.s fpmul5
	sub.b d3, d1
	bcc.s fpdiv1
	bmi.s fpdiv2
	bpl.s fpmul0
fpdiv1:
	bmi ovfw
fpdiv2:
	add.b #129, d1
	clr.b d3
	eor.w d3, d1
	moveq #0, d3
	moveq #0, d5
	bcs.s .+6
	cmp.l d2, d0
	bcs.s .+8
	sub.l d2, d0
	or.w #0x8000, d5
	add.l d0, d0
	bcs.s .+6
	cmp.l d2, d0
	bcs.s .+8
	sub.l d2, d0
	or.w #0x4000, d5
	add.l d0, d0
	bcs.s .+6
	cmp.l d2, d0
	bcs.s .+8
	sub.l d2, d0
	or.w #0x2000, d5
	add.l d0, d0
	bcs.s .+6
	cmp.l d2, d0
	bcs.s .+8
	sub.l d2, d0
	or.w #0x1000, d5
	add.l d0, d0
	bcs.s .+6
	cmp.l d2, d0
	bcs.s .+8
	sub.l d2, d0
	or.w #0x800, d5
	add.l d0, d0
	bcs.s .+6
	cmp.l d2, d0
	bcs.s .+8
	sub.l d2, d0
	or.w #0x400, d5
	add.l d0, d0
	bcs.s .+6
	cmp.l d2, d0
	bcs.s .+8
	sub.l d2, d0
	or.w #0x200, d5
	add.l d0, d0
	bcs.s .+6
	cmp.l d2, d0
	bcs.s .+8
	sub.l d2, d0
	or.w #0x100, d5
	add.l d0, d0
	bcs.s .+6
	cmp.l d2, d0
	bcs.s .+8
	sub.l d2, d0
	or.w #0x80, d5
	add.l d0, d0
	bcs.s .+6
	cmp.l d2, d0
	bcs.s .+8
	sub.l d2, d0
	or.w #0x40, d5
	add.l d0, d0
	bcs.s .+6
	cmp.l d2, d0
	bcs.s .+8
	sub.l d2, d0
	or.w #0x20, d5
	add.l d0, d0
	bcs.s .+6
	cmp.l d2, d0
	bcs.s .+8
	sub.l d2, d0
	or.w #0x10, d5
	add.l d0, d0
	bcs.s .+6
	cmp.l d2, d0
	bcs.s .+8
	sub.l d2, d0
	or.w #0x8, d5
	add.l d0, d0
	bcs.s .+6
	cmp.l d2, d0
	bcs.s .+8
	sub.l d2, d0
	or.w #0x4, d5
	add.l d0, d0
	bcs.s .+6
	cmp.l d2, d0
	bcs.s .+8
	sub.l d2, d0
	or.w #0x2, d5
	add.l d0, d0
	bcs.s .+6
	cmp.l d2, d0
	bcs.s .+8
	sub.l d2, d0
	or.w #0x1, d5
	swap d5
	add.l d0, d0
	bcs.s .+6
	cmp.l d2, d0
	bcs.s .+8
	sub.l d2, d0
	or.w #0x8000, d5
	add.l d0, d0
	bcs.s .+6
	cmp.l d2, d0
	bcs.s .+8
	sub.l d2, d0
	or.w #0x4000, d5
	add.l d0, d0
	bcs.s .+6
	cmp.l d2, d0
	bcs.s .+8
	sub.l d2, d0
	or.w #0x2000, d5
	add.l d0, d0
	bcs.s .+6
	cmp.l d2, d0
	bcs.s .+8
	sub.l d2, d0
	or.w #0x1000, d5
	add.l d0, d0
	bcs.s .+6
	cmp.l d2, d0
	bcs.s .+8
	sub.l d2, d0
	or.w #0x800, d5
	add.l d0, d0
	bcs.s .+6
	cmp.l d2, d0
	bcs.s .+8
	sub.l d2, d0
	or.w #0x400, d5
	add.l d0, d0
	bcs.s .+6
	cmp.l d2, d0
	bcs.s .+8
	sub.l d2, d0
	or.w #0x200, d5
	add.l d0, d0
	bcs.s .+6
	cmp.l d2, d0
	bcs.s .+8
	sub.l d2, d0
	or.w #0x100, d5
	add.l d0, d0
	bcs.s .+6
	cmp.l d2, d0
	bcs.s .+8
	sub.l d2, d0
	or.w #0x80, d5
	add.l d0, d0
	bcs.s .+6
	cmp.l d2, d0
	bcs.s .+8
	sub.l d2, d0
	or.w #0x40, d5
	add.l d0, d0
	bcs.s .+6
	cmp.l d2, d0
	bcs.s .+8
	sub.l d2, d0
	or.w #0x20, d5
	add.l d0, d0
	bcs.s .+6
	cmp.l d2, d0
	bcs.s .+8
	sub.l d2, d0
	or.w #0x10, d5
	add.l d0, d0
	bcs.s .+6
	cmp.l d2, d0
	bcs.s .+8
	sub.l d2, d0
	or.w #0x8, d5
	add.l d0, d0
	bcs.s .+6
	cmp.l d2, d0
	bcs.s .+8
	sub.l d2, d0
	or.w #0x4, d5
	add.l d0, d0
	bcs.s .+6
	cmp.l d2, d0
	bcs.s .+8
	sub.l d2, d0
	or.w #0x2, d5
	add.l d0, d0
	bcs.s .+6
	cmp.l d2, d0
	bcs.s .+8
	sub.l d2, d0
	or.w #0x1, d5
	add.l d0, d0
	bcs.s fpdiv6
	cmp.l d2, d0
	bcs.s fpdiv7
fpdiv6:
	sub.l d2, d0
	or.w #0x8000, d3
fpdiv7:
	add.l d0, d0
	bcs.s fpdiv8
	cmp.l d2, d0
	bcs.s fpdiv9
fpdiv8:
	or.w #0x4000, d3
fpdiv9:
	move.l d5, d0
	bra fpmuln

/* Floating point square root
 * Uses Newton-Raphson algorithm
 */
negroot:
	trap #err
	dc.b 21
.ascii  "-ve root"
	dc.b  0
.align 2

sqr:
	tst.b d1
	beq.s sqr0
	tst.w d1
	bmi.s negroot
	sub.b #128, d1
	move.b d1, -(a7)
	move.l d0, d2
	asr.l #1, d0
	and.b #1, d1
	beq.s sqr1
	bclr #30, d0
sqr1:
	bsr.s sqrd
	bsr.s sqrd
	bsr.s sqrd
	moveq #0, d1
	moveq #-128, d2
	move.b (a7)+, d1
	asr.b #1, d1
	addx.b d2, d1
sqr0:
	rts
sqrd:
	move.l d2, d1
	moveq #0, d3
	cmp.l d0, d1
	bcc.s sqrd1
	add.l d1, d1
sqrd1:
	bcs.s .+6
	cmp.l d0, d1
	bcs.s .+8
	sub.l d0, d1
	or.w #0x8000, d3
	add.l d1, d1
	bcs.s .+6
	cmp.l d0, d1
	bcs.s .+8
	sub.l d0, d1
	or.w #0x4000, d3
	add.l d1, d1
	bcs.s .+6
	cmp.l d0, d1
	bcs.s .+8
	sub.l d0, d1
	or.w #0x2000, d3
	add.l d1, d1
	bcs.s .+6
	cmp.l d0, d1
	bcs.s .+8
	sub.l d0, d1
	or.w #0x1000, d3
	add.l d1, d1
	bcs.s .+6
	cmp.l d0, d1
	bcs.s .+8
	sub.l d0, d1
	or.w #0x800, d3
	add.l d1, d1
	bcs.s .+6
	cmp.l d0, d1
	bcs.s .+8
	sub.l d0, d1
	or.w #0x400, d3
	add.l d1, d1
	bcs.s .+6
	cmp.l d0, d1
	bcs.s .+8
	sub.l d0, d1
	or.w #0x200, d3
	add.l d1, d1
	bcs.s .+6
	cmp.l d0, d1
	bcs.s .+8
	sub.l d0, d1
	or.w #0x100, d3
	add.l d1, d1
	bcs.s .+6
	cmp.l d0, d1
	bcs.s .+8
	sub.l d0, d1
	or.w #0x80, d3
	add.l d1, d1
	bcs.s .+6
	cmp.l d0, d1
	bcs.s .+8
	sub.l d0, d1
	or.w #0x40, d3
	add.l d1, d1
	bcs.s .+6
	cmp.l d0, d1
	bcs.s .+8
	sub.l d0, d1
	or.w #0x20, d3
	add.l d1, d1
	bcs.s .+6
	cmp.l d0, d1
	bcs.s .+8
	sub.l d0, d1
	or.w #0x10, d3
	add.l d1, d1
	bcs.s .+6
	cmp.l d0, d1
	bcs.s .+8
	sub.l d0, d1
	or.w #0x8, d3
	add.l d1, d1
	bcs.s .+6
	cmp.l d0, d1
	bcs.s .+8
	sub.l d0, d1
	or.w #0x4, d3
	add.l d1, d1
	bcs.s .+6
	cmp.l d0, d1
	bcs.s .+8
	sub.l d0, d1
	or.w #0x2, d3
	add.l d1, d1
	bcs.s .+6
	cmp.l d0, d1
	bcs.s .+8
	sub.l d0, d1
	or.w #0x1, d3
	swap d3
	add.l d1, d1
	bcs.s .+6
	cmp.l d0, d1
	bcs.s .+8
	sub.l d0, d1
	or.w #0x8000, d3
	add.l d1, d1
	bcs.s .+6
	cmp.l d0, d1
	bcs.s .+8
	sub.l d0, d1
	or.w #0x4000, d3
	add.l d1, d1
	bcs.s .+6
	cmp.l d0, d1
	bcs.s .+8
	sub.l d0, d1
	or.w #0x2000, d3
	add.l d1, d1
	bcs.s .+6
	cmp.l d0, d1
	bcs.s .+8
	sub.l d0, d1
	or.w #0x1000, d3
	add.l d1, d1
	bcs.s .+6
	cmp.l d0, d1
	bcs.s .+8
	sub.l d0, d1
	or.w #0x800, d3
	add.l d1, d1
	bcs.s .+6
	cmp.l d0, d1
	bcs.s .+8
	sub.l d0, d1
	or.w #0x400, d3
	add.l d1, d1
	bcs.s .+6
	cmp.l d0, d1
	bcs.s .+8
	sub.l d0, d1
	or.w #0x200, d3
	add.l d1, d1
	bcs.s .+6
	cmp.l d0, d1
	bcs.s .+8
	sub.l d0, d1
	or.w #0x100, d3
	add.l d1, d1
	bcs.s .+6
	cmp.l d0, d1
	bcs.s .+8
	sub.l d0, d1
	or.w #0x80, d3
	add.l d1, d1
	bcs.s .+6
	cmp.l d0, d1
	bcs.s .+8
	sub.l d0, d1
	or.w #0x40, d3
	add.l d1, d1
	bcs.s .+6
	cmp.l d0, d1
	bcs.s .+8
	sub.l d0, d1
	or.w #0x20, d3
	add.l d1, d1
	bcs.s .+6
	cmp.l d0, d1
	bcs.s .+8
	sub.l d0, d1
	or.w #0x10, d3
	add.l d1, d1
	bcs.s .+6
	cmp.l d0, d1
	bcs.s .+8
	sub.l d0, d1
	or.w #0x8, d3
	add.l d1, d1
	bcs.s .+6
	cmp.l d0, d1
	bcs.s .+8
	sub.l d0, d1
	or.w #0x4, d3
	add.l d1, d1
	bcs.s .+6
	cmp.l d0, d1
	bcs.s .+8
	sub.l d0, d1
	or.w #0x2, d3
	add.l d1, d1
	bcs.s .+6
	cmp.l d0, d1
	bcs.s .+8
	sub.l d0, d1
	or.w #0x1, d3
	add.l d1, d1
	add.l d3, d0
	roxr.l #1, d0
	bcc.s sqrd4
	addq.l #1, d0
sqrd4:
	rts

/* Integer to floating point conversion */
intfp:
	move.w #160, d1
	tst.l d0
	beq.s intfp0
	bpl.s intfp1
	neg.l d0
	move.w #0xffa0, d1
intfp1:
	swap d0
	tst.w d0
	bne.s intfp2
	sub.b #16, d1
	swap d0
intfp2:
	swap d0
	bmi.s intfp3
	subq.b #1, d1
intfp4:
	add.l d0, d0
	dbmi d1, intfp4
intfp3:
	rts
intfp0:
	clr.b d1
	rts

/* Floating point to integer conversion */
fpint:
	cmp.b #128, d1
	bls.s fpint0
	cmp.b #159, d1
	bhi ovfw
	sub.b #160, d1
	neg.b d1
	lsr.l d1, d0
	tst.w d1
	bpl.s fpint1
	neg.l d0
fpint1:
	rts
fpint0:
	moveq #0, d0
	rts

/* ASCII text to floating point conversion */
ascfp:
	moveq #0, d0
	moveq #0, d1
	moveq #0, d5
ascfp1:
	moveq #0, d2
	move.b (a6)+, d2
	cmp.b #46, d2
	beq.s ascfpdp
	cmp.b #0x45, d2
	beq.s ascfpex
	sub.b #48, d2
	bcs ascfpnd
	cmp.b #9, d2
	bhi ascfpnd
	tst.b d1
	beq.s ascfp4
	addq.b #3, d1
	bcs ovfw
	move.l d0, d4
	lsr.l #2, d0
	add.l d4, d0
	bcc.s ascfp3
	roxr.l #1, d0
	scs d4
	addq.b #1, d1
	bcs ovfw
ascfp3:
	lsr.b #2, d4
	moveq #0, d4
	addx.l d4, d0
	bcc.s ascfp4
	roxr.l #1, d0
	addq.b #1, d1
	bcs ovfw
ascfp4:
	exg d0, d2
	move.l d1, d3
	bsr intfp
	bsr fpadd
	tst.w d5
	bpl ascfp1
	addq.b #1, d5
	bra ascfp1
ascfpdp:
	move.w #0xff00, d5
	bra ascfp1
ascfpex:
	bsr.s ascfpnd1
	moveq #0, d5
	move.b (a6)+, d2
	cmp.b #43, d2
	beq.s ascfpex1b
	cmp.b #45, d2
	bne.s ascfpex1a
	bset #15, d5
	bra.s ascfpex1b
ascfpex1a:
	subq.l #1, a6
ascfpex1b:
	move.l a6, -(a7)
ascfpex1:
	move.b (a6)+, d2
	sub.b #48, d2
	bcs.s ascfpex2
	cmp.b #9, d2
	bhi.s ascfpex2
	add.b d5, d5
	add.b d5, d2
	bcs.s badexp
	add.b d5, d5
	bcs.s badexp
	add.b d5, d5
	bcs.s badexp
	add.b d2, d5
	bcs.s badexp
	bra.s ascfpex1
ascfpex2:
	subq.l #1, a6
	cmp.l (a7)+, a6
	beq badexp
	cmp.b #38, d5
	bhi.s badexp
	moveq #0, d2
	move.b d5, d2
	mulu #6, d2
	lea pwrtab-.-2(pc, d2.w), a0
	move.w (a0)+, d3
	move.l (a0)+, d2
	tst.w d5
	bmi fpdiv
	bra fpmul
ascfpnd:
	subq.l #1, a6
ascfpnd1:
	tst.w d5
	bpl.s ascfpnd2
	and.w #255, d5
	mulu #6, d5
	lea pwrtab-.-2(pc, d5.w), a0
	move.w (a0)+, d3
	move.l (a0)+, d2
	bra fpdiv
ascfpnd2:
	rts
badexp:
	trap #err
	dc.b 50
.ascii  "Bad exponent"
	dc.b  0

/* Table of powers of 10 from 10^0 to 10^38 */
.align 2
pwrtab:
	dc.w 0x81
	dc.l 0x80000000
	dc.w 0x84
	dc.l 0xa0000000
	dc.w 0x87
	dc.l 0xc8000000
	dc.w 0x8a
	dc.l 0xfa000000
	dc.w 0x8e
	dc.l 0x9c400000
	dc.w 0x91
	dc.l 0xc3500000
	dc.w 0x94
	dc.l 0xf4240000
	dc.w 0x98
	dc.l 0x98968000
	dc.w 0x9b
	dc.l 0xbebc2000
	dc.w 0x9e
	dc.l 0xee6b2800
	dc.w 0xa2
	dc.l 0x9502f900
	dc.w 0xa5
	dc.l 0xba43b740
	dc.w 0xa8
	dc.l 0xe8d4a510
	dc.w 0xac
	dc.l 0x9184e72a
	dc.w 0xaf
	dc.l 0xb5e620f4
	dc.w 0xb2
	dc.l 0xe35fa932
	dc.w 0xb6
	dc.l 0x8e1bc9bf
	dc.w 0xb9
	dc.l 0xb1a2bc2f
	dc.w 0xbc
	dc.l 0xde0b6b3a
	dc.w 0xc0
	dc.l 0x8ac72305
	dc.w 0xc3
	dc.l 0xad78ebc6
	dc.w 0xc6
	dc.l 0xd8d726b7
	dc.w 0xca
	dc.l 0x87867832
	dc.w 0xcd
	dc.l 0xa968163f
	dc.w 0xd0
	dc.l 0xd3c21bcf
	dc.w 0xd4
	dc.l 0x84595161
	dc.w 0xd7
	dc.l 0xa56fa5ba
	dc.w 0xda
	dc.l 0xcecb8f28
	dc.w 0xde
	dc.l 0x813f3979
	dc.w 0xe1
	dc.l 0xa18f07d7
	dc.w 0xe4
	dc.l 0xc9f2c9cd
	dc.w 0xe7
	dc.l 0xfc6f7c40
	dc.w 0xeb
	dc.l 0x9dc5ada8
	dc.w 0xee
	dc.l 0xc5371912
	dc.w 0xf1
	dc.l 0xf684df57
	dc.w 0xf5
	dc.l 0x9a130b96
	dc.w 0xf8
	dc.l 0xc097ce7c
	dc.w 0xfb
	dc.l 0xf0bdc21b
	dc.w 0xff
	dc.l 0x96769951

fpasc0:
	move.b #48, (a0)+
	move.b #13, (a0)+
	rts

/* Floating point to ASCII text conversion */
fpasc:
	tst.b d1
	beq.s fpasc0
	tst.w d1
	bpl.s fpasc1
	move.b #45, (a0)+
fpasc1:
	and.w #0xff, d1
	cmp.b #129, d1
	bcs.s fpasc2
	cmp.b #132, d1
	bhi.s fpasc3
	cmp.l #0xa0000000, d0
	bcs.s fpasc4
fpasc3:
	lea pwrtab-.-2(pc), a1
	moveq #0, d2
fpasc3a:
	addq.l #6, a1
	addq.b #1, d2
	cmp.w (a1), d1
	bhi.s fpasc3a
	bcs.s fpasc3b
	cmp.l 2(a1), d0
	bcc.s fpasc3c
fpasc3b:
	subq.l #6, a1
	subq.b #1, d2
fpasc3c:
	move.b d2, -(a7)
	move.w (a1)+, d3
	move.l (a1), d2
	bsr fpdiv
	bra.s fpasc4a
fpasc2:
	lea pwrtab-.-2(pc), a1
	moveq #0, d2
	move.w d1, d3
	neg.b d3
fpasc2a:
	addq.l #6, a1
	subq.b #1, d2
	cmp.w (a1), d3
	bhi.s fpasc2a
	move.b d2, -(a7)
	move.w (a1)+, d3
	move.l (a1), d2
	bsr fpmul
	cmp.b #128, d1
	bhi.s fpasc2b
	move.w #0x84, d3
	move.l #0xa0000000, d2
	bsr fpmul
	subq.b #1, (a7)
fpasc2b:
	bra.s fpasc4a
fpasc4:
	clr.b -(a7)
fpasc4a:
	moveq #0, d3
	move.b d1, d3
	sub.w #129, d3
	moveq #0, d2
fpasc4b:
	add.l d0, d0
	addx.b d2, d2
	dbra d3, fpasc4b
	add.b #48, d2
	move.b d2, (a0)+
	moveq #8, d3
	tst.b d6
	beq.s fpasc4c
	move.b #46, (a0)+
fpasc4c:
	moveq #0, d2
	move.l d0, -(a7)
	add.l d0, d0
	addx.b d2, d2
	add.l d0, d0
	addx.b d2, d2
	add.l (a7)+, d0
	moveq #0, d1
	addx.b d1, d2
	add.l d0, d0
	addx.b d2, d2
	add.b #48, d2
	move.b d2, (a0)+
	dbra d3, fpasc4c
fpasc5:
	moveq #0, d0
	move.b (a7)+, d0
	beq.s fpasc6
	tst.b d6
	beq.s fpasc6
	move.b #0x45, (a0)+
	tst.b d0
	bpl.s fpasc5a
	neg.b d0
	move.b #45, (a0)+
fpasc5a:
	divu #10, d0
	tst.w d0
	beq.s fpasc5b
	add.b #48, d0
	move.b d0, (a0)+
fpasc5b:
	swap d0
	add.b #48, d0
	move.b d0, (a0)+
fpasc6:
	move.b #13, (a0)+
	rts

/* FRAC function implementation */
frac:
	cmp.b #159, d1
	bcc.s frac0
	cmp.b #128, d1
	bls.s frac1
	sub.b #128, d1
	asl.l d1, d0
	move.b #128, d1
	tst.l d0
	beq.s frac0
	bmi.s frac1
	subq.b #1, d1
frac2:
	add.l d0, d0
	dbmi d1, frac2
frac1:
	rts
frac0:
	clr.b d1
	rts

/* EXP function implementation */
exptab1:
	dc.w 0x81
	dc.l 0xd3094c71
	dc.w 0x82
	dc.l 0xadf85459
	dc.w 0x83
	dc.l 0x8f69ff32
	dc.w 0x83
	dc.l 0xec7325c7
	dc.w 0x84
	dc.l 0xc2eb7eca
	dc.w 0x85
	dc.l 0xa0af2dfb
	dc.w 0x86
	dc.l 0x8476390a
	dc.w 0x86
	dc.l 0xda648171
	dc.w 0x87
	dc.l 0xb408c56f
	dc.w 0x88
	dc.l 0x9469c4cc
	dc.w 0x88
	dc.l 0xf4b12279
	dc.w 0x89
	dc.l 0xc9b6e2b5
	dc.w 0x8a
	dc.l 0xa6491084
	dc.w 0x8b
	dc.l 0x891442d5
	dc.w 0x8b
	dc.l 0xe2015b76
exptab2:
	dc.w 0x02
	dc.l 0x83db8896
	dc.w 0x0d
	dc.l 0xbfecba6a
	dc.w 0x19
	dc.l 0x8bad7868
	dc.w 0x24
	dc.l 0xcb4ea399
	dc.w 0x30
	dc.l 0x93f622c6
	dc.w 0x3b
	dc.l 0xd75d5d72
	dc.w 0x47
	dc.l 0x9cbc924d
	dc.w 0x52
	dc.l 0xe42327bb
	dc.w 0x5e
	dc.l 0xa6083c7f
	dc.w 0x69
	dc.l 0xf1aaddd7
	dc.w 0x75
	dc.l 0xafe10821
exptab3:
	dc.w 0x8c
	dc.l 0xba4f53ea
	dc.w 0x98
	dc.l 0x87975e85
	dc.w 0xa3
	dc.l 0xc55bfdaa
	dc.w 0xaf
	dc.l 0x8fa1fe62
	dc.w 0xba
	dc.l 0xd11069cc
	dc.w 0xc6
	dc.l 0x9826b576
	dc.w 0xd1
	dc.l 0xdd768b53
	dc.w 0xdd
	dc.l 0xa12cc168
	dc.w 0xe8
	dc.l 0xea98ec54
	dc.w 0xf4
	dc.l 0xaabbcdcc
	dc.w 0xff
	dc.l 0xf882b6e4
expc:
	dc.w 0x77
	dc.l 0xe8575e47
	dc.w 0x7a
	dc.l 0x842efac5
	dc.w 0x7c
	dc.l 0xab07be04
	dc.w 0x7e
	dc.l 0xaaa6bd0a
	dc.w 0x80
	dc.l 0x800013b8
	dc.w 0x80
	dc.l 0xffffff78
	dc.w 0x81
	dc.l 0x80000000
exp0:
	tst.w d1
	bpl ovfw
	clr.b d1
	rts
exp01:
	move.l #0x80000000, d0
	move.w #0x81, d1
	rts
exp:
	cmp.b #0x88, d1
	bcc.s exp0
	tst.b d1
	beq.s exp01
	moveq #0, d5
	cmp.b #127, d1
	bls.s exp1
	sub.b #127, d1
	moveq #-1, d3
	asl.l d1, d3
	rol.l d1, d0
	move.l d3, d5
	not.l d5
	and.l d0, d5
	cmp.b #176, d5
	bhi.s exp0
	move.b #127, d1
	and.l d3, d0
	beq.s exp2
	bmi.s exp1
	cmp.l #0x10000, d0
	bcc.s exp3
	sub.b #16, d1
	swap d0
	bra.s exp3
exp3a:
	add.l d0, d0
exp3:
	dbmi d1, exp3a
	bra.s exp1
exp2:
	tst.w d1
	bpl.s exp2a
	neg.w d5
exp2a:
	clr.w d1
exp1:
	tst.w d1
	bpl.s exp4
	not.w d5
	move.w #0x80, d3
	move.l #0x80000000, d2
	bsr fpadd
exp4:
	move.w d5, -(a7)
	lea expc-.-2(pc), a0
	moveq #5, d6
	bsr.s series
	lea exptab3-.-8(pc), a0
	move.w (a7), d5
	asr.w #4, d5
	beq.s exp5
	bpl.s exp4a
	cmp.w #-11, d5
	blt.s exp6
	addq.l #6, a0
exp4a:
	muls #6, d5
	add.w d5, a0
	move.w (a0)+, d3
	move.l (a0)+, d2
	bsr fpmul
exp5:
	moveq #15, d5
	and.w (a7)+, d5
	beq.s exp5a
	mulu #6, d5
	lea exptab1-.-8(pc), a0
	add.w d5, a0
	move.w (a0)+, d3
	move.l (a0)+, d2
	bsr fpmul
exp5a:
	rts
exp6:
	move.w #2, d3
	move.l #0x83db8896, d2
	bsr fpmul
	move.w (a7)+, d5
	neg.w d5
	and.w #15, d5
	mulu #6, d5
	lea exptab1-.-8(pc), a0
	add.w d5, a0
	move.w (a0)+, d3
	move.l (a0)+, d2
	bra fpdiv

/* Evaluate a polynomial */
series:
	move.l d0, -(a7)
	move.w d1, -(a7)
	move.w (a0)+, d1
	move.l (a0)+, d0
series1:
	move.w (a7), d3
	move.l 2(a7), d2
	bsr fpmul
	move.w (a0)+, d3
	move.l (a0)+, d2
	bsr fpadd
	dbra d6, series1
	addq.l #6, a7
	rts

/* LN/LOG function implementation */
lntab:
	dc.w 0x7f
	dc.l 0xde574b4c
	dc.w 0x80
	dc.l 0x939b080d
	dc.w 0x80
	dc.l 0xf6389323
	dc.w 0x82
	dc.l 0xb8aa3b22
ln0:
	trap #err
	dc.b 22
.ascii  "Log range"
	dc.b  0
	dc.b  0
.align 2
log:
	moveq #-1, d6
	bra.s ln1
ln:
	moveq #0, d6
ln1:
	tst.b d1
	beq.s ln0
	tst.w d1
	bmi.s ln0
	move.w d1, -(a7)
	move.w #0x80, d1
	move.l d0, -(a7)
	move.w d1, -(a7)
	move.w d1, d3
	move.l #0xb504f334, d2
	bsr fpsub
	move.w (a7), d3
	move.l 2(a7), d2
	move.w d1, (a7)
	move.l d0, 2(a7)
	move.w #0x80, d1
	move.l #0xb504f334, d0
	bsr fpadd
	move.l d0, d2
	move.w d1, d3
	move.w (a7)+, d1
	move.l (a7)+, d0
	bsr fpdiv
	move.l d0, -(a7)
	move.w d1, -(a7)
	move.l d0, d2
	move.w d1, d3
	bsr fpmul
	lea lntab-.-2(pc), a0
	move.w #2, d6
	bsr series
	move.w (a7)+, d3
	move.l (a7)+, d2
	bsr fpmul
	move.w (a7)+, d2
	sub.b #128, d2
	ext.w d2
	add.w d2, d2
	subq.w #1, d2
	ext.l d2
	bpl.s ln2
	neg.w d2
ln2:
	swap d2
	move.w d2, d3
	clr.w d2
	move.b #0x8e, d3
ln3:
	add.l d2, d2
	dbmi d3, ln3
	bsr fpadd
	tst.l d6
	bmi.s log2
	move.w #0x80, d3
	move.l #0xb17217f8, d2
	bra fpmul
log2:
	move.w #0x7f, d3
	move.l #0x9a209a85, d2
	bra fpmul

/* ^ operator implementation for generic case */
power:
	move.l d2, -(a7)
	move.w d3, -(a7)
	bsr ln
	move.w (a7)+, d3
	move.l (a7)+, d2
	bsr fpmul
	bra exp

/* ATN function implementation */
atntab:
	dc.w 0xff76
	dc.l 0xa49cbbef
	dc.w 0x79
	dc.l 0x93f92296
	dc.w 0xff7a
	dc.l 0xf9e7e644
	dc.w 0x7c
	dc.l 0x86fd541e
	dc.w 0xff7c
	dc.l 0xd9a04c2f
	dc.w 0x7d
	dc.l 0x92fd5c87
	dc.w 0xff7d
	dc.l 0xb75df848
	dc.w 0x7d
	dc.l 0xe30d5561
	dc.w 0xff7e
	dc.l 0x9241e786
	dc.w 0x7e
	dc.l 0xcccc5731
	dc.w 0xff7f
	dc.l 0xaaaaa8ed
	dc.w 0x80
	dc.l 0xfffffffe
atn:
	tst.b d1
	beq.s atn0
	cmp.b #128, d1
	shi -(a7)
	bls.s atn1
	move.l d0, d2
	move.w d1, d3
	move.l #0x80000000, d0
	move.w #0x81, d1
	bsr fpdiv
atn1:
	move.l d0, -(a7)
	move.w d1, -(a7)
	move.l d0, d2
	move.w d1, d3
	bsr fpmul
	lea atntab-.-2(pc), a0
	moveq #10, d6
	bsr series
	move.w (a7)+, d3
	move.l (a7)+, d2
	bsr fpmul
	tst.b (a7)+
	beq.s atn0
	move.w d1, d3
	move.l d0, d2
	move.b #0x81, d1
	move.l #0xc90fdaa2, d0
	bra fpsub
atn0:
	rts

/* SIN/COS function implementation */
sintab:
	dc.w 0xff67
	dc.l 0xc9f45528
	dc.w 0x6e
	dc.l 0xb88d556d
	dc.w 0xff74
	dc.l 0xd00a5126
	dc.w 0x7a
	dc.l 0x88887f67
	dc.w 0xff7e
	dc.l 0xaaaaaa76
	dc.w 0x80
	dc.l 0xffffffff
sin0:
	trap #err
	dc.b 23
.ascii  "Accuracy lost"
	dc.b  0
	dc.b  0
.align 2
sin0a:
	clr.w d1
	rts
cos:
	move.w #0x81, d3
	and.w #0xff, d1
	move.l #0xc90fdaa2, d2
	bsr fpadd
sin:
	cmp.b #0x8a, d1
	bhi.s sin0
	move.l #0xc90fdaa2, d2
	move.b d1, d3
	sub.b #130, d3
	bcs.s sin1
	ext.w d3
	bra.s sin3
sin2:
	subq.b #1, d1
	add.l d0, d0
	scs d4
	bcs.s sin2a
sin3:
	cmp.l d2, d0
	scc d4
	bcs.s sin2b
sin2a:
	sub.l d2, d0
sin2b:
	dbra d3, sin2
	tst.l d0
	beq.s sin0a
	ext.w d4
	clr.b d4
	eor.w d4, d1
	swap d0
	tst.w d0
	bne.s sin1a
	sub.b #16, d1
	bcs.s sin0a
	swap d0
sin1a:
	swap d0
	bmi.s sin1
	move.b d1, d3
	subq.b #1, d1
sin1b:
	add.l d0, d0
	dbmi d1, sin1b
	tst.b d1
	beq.s sin0a
	cmp.b d3, d1
	bcc.s sin0a
sin1:
	cmp.b #129, d1
	bcs.s sin4
	bhi.s sin5
	cmp.l d2, d0
	bcs.s sin4
sin5:
	exg d0, d2
	move.w d1, d3
	move.b #130, d1
	bsr fpsub
sin4:
	move.l d0, -(a7)
	move.w d1, -(a7)
	move.w d1, d3
	move.l d0, d2
	bsr fpmul
	lea sintab-.-2(pc), a0
	moveq #4, d6
	bsr series
	move.w (a7)+, d3
	move.l (a7)+, d2
	bra fpmul

/* TAN function implementation */
tan:
	move.l d0, -(a7)
	move.w d1, -(a7)
	bsr sin
	move.w (a7)+, d3
	move.l (a7)+, d2
	move.l d0, -(a7)
	move.w d1, -(a7)
	move.l d2, d0
	move.w d3, d1
	bsr cos
	move.l d0, d2
	move.w d1, d3
	move.w (a7)+, d1
	move.l (a7)+, d0
	bra fpdiv

/* ACS/ASN function implementation */
acs:
	moveq #-1, d6
	bra.s asn1
asn:
	moveq #0, d6
asn1:
	move.l d0, -(a7)
	swap d6
	tst.w d1
	smi d6
	swap d6
	and.w #0xff, d1
	move.w d1, -(a7)
	move.l d0, d2
	move.w d1, d3
	bsr fpmul
	move.w #0x81, d3
	move.l #0x80000000, d2
	bsr fpsub
	eor.w #0xff00, d1
	bsr sqr
	move.w (a7)+, d3
	move.l (a7)+, d2
	cmp.b d1, d3
	bhi.s asn2
	bcs.s asn2a
	cmp.l d0, d2
	bcc.s asn2
asn2a:
	exg d0, d2
	exg d1, d3
	bchg #30, d6
asn2:
	bsr fpdiv
	move.l d0, -(a7)
	move.w d1, -(a7)
	move.l d0, d2
	move.w d1, d3
	bsr fpmul
	lea atntab-.-2(pc), a0
	move.w #10, d6
	bsr series
	move.w (a7)+, d3
	move.l (a7)+, d2
	bsr fpmul
	swap d6
	move.b d6, d3
	ext.w d3
	move.b d1, d3
	move.w d3, d1
	add.w d6, d6
	bcs.s acs1
	bmi.s asn0
	eor.w #0xff00, d1
	move.l #0xc90fdaa2, d2
	move.b #0x81, d3
	bra fpadd
acs1:
	bpl.s acs2
	tst.w d1
	bpl.s asn0
	move.l #0xc90fdaa2, d2
	move.w #0x82, d3
	bra fpadd
acs2:
	eor.w #0xff00, d1
	move.l #0xc90fdaa2, d2
	move.w #0x81, d3
	bra fpadd
asn0:
	rts

/* Character categorization table for operand evaluation */
chrtb:
	dc.l 0, 0, 0, 0, 0, 0, 0, 0     /* 00 - 1F */
	dc.b 26     /* 20 space */
	dc.b  8     /* 21 ! */
	dc.b  22    /* 22 " */
	dc.b  0     /* 23 # */
	dc.b  12    /* 24 $ */
	dc.b  0     /* 25 % */
	dc.b  14    /* 26 & */
	dc.b  0     /* 27 ' */
	dc.b  6     /* 28 ( */
	dc.b  0     /* 29 ) */
	dc.b  0     /* 2A * */
	dc.b  4     /* 2B + */
	dc.b  0     /* 2C , */
	dc.b  2     /* 2D - */
	dc.b  28    /* 2E . */
	dc.b  0     /* 2F / */
	dc.b 16     /* 30 0 */
	dc.b  16
	dc.b  16
	dc.b  16
	dc.b  16
	dc.b  16
	dc.b  16
	dc.b  16
	dc.b  16
	dc.b  16    /* 39 9 */
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  10    /* 3F ? */
	dc.b 24     /* 40 @ */
	dc.b  18    /* 41 A */
	dc.b  18
	dc.b  18
	dc.b  18
	dc.b  18
	dc.b  18
	dc.b  18
	dc.b  18
	dc.b  18
	dc.b  18
	dc.b  18
	dc.b  18
	dc.b  18
	dc.b  18
	dc.b  18
	dc.b 18
	dc.b  18
	dc.b  18
	dc.b  18
	dc.b  18
	dc.b  18
	dc.b  18
	dc.b  18
	dc.b  18
	dc.b  18
	dc.b  18    /* 5A Z */
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b 0
	dc.b  20    /* 61 a */
	dc.b  20
	dc.b  20
	dc.b  20
	dc.b  20
	dc.b  20
	dc.b  20
	dc.b  20
	dc.b  20
	dc.b  20
	dc.b  20
	dc.b  20
	dc.b  20
	dc.b  20
	dc.b  20
	dc.b 20
	dc.b  20
	dc.b  20
	dc.b  20
	dc.b  20
	dc.b  20
	dc.b  20
	dc.b  20
	dc.b  20
	dc.b  20
	dc.b  20    /* 7A z */
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  0
	dc.b  0     /* 7F DEL */

/* Jump table for operand evaluation, indexed by result of chrtb lookup */
.align 2
chjt:
	dc.w syntax-chjt, minus-chjt, plus-chjt, brkt-chjt, qeekfn-chjt
	dc.w peekfn-chjt, strpeek-chjt, hexnum-chjt, number-chjt, varc-chjt
	dc.w vars-chjt, string-chjt, format-chjt, operand-chjt, number5-chjt

/* Evaluate a single operand in an expression
 * An operand is one of the following:
 *  A numeric or string literal
 *  A unary operator (+, -, ?, !, $) followed by another operand
 *  A variable - either a simple variable or a subscripted array element
 *  An entire expression surrounded by parentheses
 *  A call to a built-in or user-defined function
 *
 * Return result:
 *  D6.B = 00 for integer value, value returned in D0
 *  D6.B = 01 for floating point value, value returned in D1/D0
 *  D6.B = FF for string value, string pointed to by A0, length in D0 (<=255)
 */
typemis:
	trap #err
	dc.b 6
.ascii  "Type mismatch"
	dc.b  0
	dc.b  0
.align 2
operand:
	move.b (a6)+, d0
	bmi function
	ext.w d0
	moveq #0, d5
	lea chrtb-.-2(pc), a0
	move.b 0(a0, d0.w), d5
	lea chjt-.-2(pc), a0
	add.w 0(a0, d5.w), a0
	jmp (a0)

/* Deal with -OP */
minus:
	bsr.s operand
negnum:
	tst.b d6
	bmi.s typemis
	bne.s oper0a
	neg.l d0
	rts
oper0a:
	eor.w #0xff00, d1
	rts

/* Deal with +OP */
plus:
	bsr.s operand
	tst.b d6
	bmi.s typemis
	rts

/* Deal with (EXPR) */
brkt:
	bsr expr
	cmp.b #41, (a6)+
	bne.s msngbrkt
	rts
msngbrkt:
	trap #err
	dc.b 27
.ascii  "Missing )"
	dc.b  0
	dc.b  0
.align 2
syntax:
	trap #err
	dc.b 16
.ascii  "Syntax error"
	dc.b  0
.align 2
msngquot:
	trap #err
	dc.b 9
.ascii  "Missing "
	dc.b  34
	dc.b  0
	dc.b  0
.align 2

/* Deal with string literals */
string:
	lea strbf, a0
	moveq #34, d0
	moveq #13, d1
	subq.l #1, a6
string0:
	addq.l #1, a6
string1:
	move.b (a6)+, (a0)
	cmp.b (a0), d1
	beq.s msngquot
	cmp.b (a0)+, d0
	bne.s string1
	cmp.b (a6), d0
	beq.s string0
	move.b #13, -(a0)
	move.l a0, d0
	lea strbf, a0
	sub.l a0, d0
	moveq #-1, d6
	rts

/* Deal with numeric literals */
number:
	subq.l #1, a6
number4:
	moveq #48, d1
	moveq #9, d2
	move.l #214748364, d4
	moveq #0, d3
	move.l a6, a0
	moveq #0, d0
number1:
	move.b (a0)+, d0
	sub.b d1, d0
	bcs.s number2
	cmp.b d2, d0
	bhi.s number2
	cmp.l d4, d3
	bhi.s number3
	move.l d3, d5
	asl.l #2, d3
	add.l d5, d3
	add.l d3, d3
	add.l d0, d3
	bvc.s number1
number3:
	bsr ascfp
	moveq #1, d6
	rts
number5:
	subq.l #1, a6
	bra.s number3
number2:
	move.b -(a0), d0
	cmp.b #46, d0
	beq.s number3
	cmp.b #0x45, d0
	beq.s number3
	move.l a0, a6
	move.l d3, d0
	moveq #0, d6
	rts

/* Deal with ?OP */
peekfn:
	bsr intarg
	move.l d0, a0
	moveq #0, d0
	move.b (a0), d0
	moveq #0, d6
	rts

/* Deal with !OP */
qeekfn:
	bsr intarg
	btst #0, d0
	bne.s aerr
	move.l d0, a0
	move.l (a0), d0
	moveq #0, d6
	rts
aerr:
	trap #err
	dc.b 51
.ascii  "Address error"
	dc.b  0
	dc.b  0
.align 2

/* Deal with $OP */
strpeek:
	bsr intarg
	move.l d0, a0
	move.l a0, a1
	move.w #255, d1
	moveq #13, d0
strpeek2:
	cmp.b (a1)+, d0
	dbeq d1, strpeek2
	bne.s strlong
	move.l a1, d0
	sub.l a0, d0
	subq.l #1, d0
	moveq #-1, d6
	rts
strlong:
	trap #err
	dc.b 19
.ascii  "String too long"
	dc.b  0
	dc.b  0
.align 2

/* Deal with hexadecimal numeric literals */
hexnum:
	move.l a6, a0
	moveq #0x16, d0
	trap #gen
	move.l a0, a6
	moveq #0, d6
	rts

/* VARIABLE STORAGE FORMAT
   Each variable is stored in a data block as follows
        addr...addr+3       Address of next variable beginning with same letter (0 if none)
        addr+4 to addr+n-1  Name, not including first letter, but including %, $ or ( for
                            integer, string, array, respectively. Terminated with a zero
                            byte, and padded with an extra byte if necessary to make the
                            total length even, so n is even.
        For integer:
            addr+n          4 byte field containing value
        For float:
            addr+n          6 byte field containing value - sign, exponent, mantissa
        For string:
            addr+n          4 byte field containing address of actual string
            addr+n+4        1 byte field containing amount of memory allocated for the string
            addr+n+5        1 byte field containing the length of the string currently stored
        For array:
            addr+n          2 byte field containing length of array header = m = 2 + 2*number of dimensions
            addr+n+2        2 byte field containing size of 1st dimension
            addr+n+4        2 byte field containing size of 2nd dimension
            ...
            addr+n+m        Elements in order (0,0,...,0,0) (0,0,...0,1) ... (0,0,...,0,k-1) (0,0,...,1,0) ...
                            Each element has the same format as for a simple variable
                            4 bytes for int, 6 bytes for float, 6 bytes for string
 */

/* Deal with @% */
format:
	cmp.b #0x25, (a6)+
	bne syntax
	moveq #0, d6
	move.l formvar, d0
	rts

/* Deal with variables beginning with an uppercase letter */
varc:
	sub.b #65, d0
	add.w d0, d0
	add.w d0, d0
	cmp.b #0x25, (a6)+      /* Test for resident integer variables A%-Z% */
	bne.s varc1             /* Branch out if not */
	cmp.b #40, (a6)         /* Test for array */
	beq.s varc1             /* Branch out if array */
	lea resint, a0
	move.l 0(a0, d0.w), d0  /* Otherwise get value from list of resident integer variables */
	moveq #0, d6            /* Data type = integer */
	rts
varc1:
	subq.l #1, a6
	lea varca, a0
	add.w d0, a0            /* A0 points to list to search, based on first character of name */
	bra.s var

/* Deal with variables beginning with a lowercase letter */
vars:
	sub.b #97, d0
	add.w d0, d0
	add.w d0, d0
	lea varsa, a0
	add.w d0, a0            /* A0 points to list to search, based on first character of name */

/* Generic variable access */
var:
	bsr.s findvar           /* Look up variable, return value if simple */
	bvs.s rdarray           /* V flag set means array, so go and evaluate subscripts */
	bcs.s nosuch            /* C flag set means variable name not found */
	rts
nosuch:
	trap #err
	dc.b 26
.ascii  "No such variable"
	dc.b  0
.align 2
rdarray:
	bcc arrayacc            /* array variable found */
nosch2:
	trap #err
	dc.b 14
.ascii  "No such array"
	dc.b  0
	dc.b  0
.align 2

/* Come here if variable name lookup fails */
notfnd:
	move.l a6, a1           /* A1 points to 2nd char of name */
	move.w #1, -(a7)        /* Will be loaded into CCR on return - sets C flag */
ntfd1:
	moveq #-33, d0          /* D0 = 0xDF */
	and.b (a1)+, d0         /* D0 = next char of name which wasn't found with bit 5 cleared */
	cmp.b #16, d0
	bcs.s ntfd2             /* branch out if not alphanumeric */
	cmp.b #0x19, d0
	bls.s ntfd1             /* loop if alphanumeric */
	cmp.b #0x41, d0
	bcs.s ntfd2             /* branch out if not alphanumeric */
	cmp.b #0x5a, d0
	bls.s ntfd1             /* loop if alphanumeric */
ntfd2:
	move.b -1(a1), d0       /* get first non-alphanumeric char */
	cmp.b d3, d0
	beq.s fparnf            /* if (, float array not found */
	cmp.b d1, d0
	beq.s intnf             /* if %, integer or integer array not found */
	cmp.b d2, d0
	beq.s strnf             /* if $, string or string array not found */
	moveq #1, d6            /* else float variable not found - D6 = float type indicator */
	rtr                     /* return with C=1 V=0 */
fparnf:
	moveq #1, d6
arnf:
	or.w #2, (a7)           /* Array reference not found - modify stack top so C=V=1 on return */
	rtr                     /* Return with C and V flags set */
intnf:
	moveq #0, d6            /* Integer variable not found, D6 = integer type indicator */
intnf1:
	cmp.b (a1)+, d3         /* Check for ( after name */
	beq.s arnf              /* If so, integer array */
	subq.l #1, a1
	rtr                     /* else return C=1 V=0 */
strnf:
	moveq #-1, d6           /* String variable not found, D6 = string type indicator */
	bra.s intnf1            /* Check for array */

/* Search a list of variables pointed to by A0
 */
findvar:
	moveq #0x25, d1
	moveq #0x24, d2
	moveq #0x28, d3
var2:
	move.l a0, a2
	move.l (a0), d0         /* D0 points to next entry to check */
	beq.s notfnd            /* If zero, end of list -> not found */
	move.l d0, a0           /* Next entry pointer to A0 */
	move.l d0, a2
	move.l a6, a1           /* A6 points to second char of variable name being searched for */
	addq.l #4, a2
var1:
	cmpm.b (a2)+, (a1)+     /* Check name against list entry */
	beq.s var1              /* Loop until mismatch found */
	tst.b -1(a2)            /* NUL character in list entry name? */
	bne.s var2              /* If not, names don't match, so onto next entry */
	subq.l #2, a1           /* A1 points to character before the one in program text corresponding to NUL (last char of name) */
	move.b (a1)+, d0        /* Get it */
	cmp.b d1, d0            /* Is it % ? */
	beq.s intvar            /* Yes - integer variable */
	cmp.b d2, d0            /* Is it $ ? */
	beq.s strvar            /* Yes - string variable */
	cmp.b d3, d0            /* Is it ( ? */
	beq array               /* Yes - array element */
	move.b (a1), d0         /* None of those - get following character */
	cmp.b d1, d0            /* Is it % ? */
	beq.s var2              /* If yes, doesn't match - looking for ABC%, found ABC */
	cmp.b d2, d0            /* Is it $ ? */
	beq.s var2              /* If yes, doesn't match - looking for ABC$, found ABC */
	cmp.b d3, d0            /* Is it ( ? */
	beq.s var2              /* If yes, doesn't match - looking for ABC(, found ABC */
	cmp.b #48, d0           /* Check for alphanumeric */
	bcs.s fpvar             /* If not, matching floating point variable found */
	cmp.b #57, d0
	bls.s var2              /* If yes, doesn't match - looking for ABCD, found ABC */
	and.b #0xdf, d0
	cmp.b #65, d0
	bcs.s fpvar
	cmp.b #90, d0
	bls.s var2
fpvar:
	move.l a1, a6           /* FP variable found, step current program location past it */
	move.l a2, d0           /* Get pointer to variable entry */
	addq.l #1, d0
	and.w #0xfffe, d0
	move.l d0, a0           /* Step to next even address */
	move.w (a0), d1         /* Sign/exp into D1 */
	move.l 2(a0), d0        /* Mantissa into D0 */
	moveq #1, d6            /* FP type indicator */
	rts
intvar:
	cmp.b (a1), d3          /* Integer variable, but check if array wanted */
	beq var2                /* If yes, no match - looking for ABC%(, found ABC% */
	move.l a1, a6           /* Integer variable found, step current program location past it */
	move.l a2, d0           /* Get pointer to variable entry */
	addq.l #1, d0
	and.w #0xfffe, d0
	move.l d0, a0           /* Step to next even address */
	move.l (a0), d0         /* Integer value into D0 */
	moveq #0, d6            /* Integer type indicator */
	rts
strvar:
	cmp.b (a1), d3          /* String variable, but check if array wanted */
	beq var2                /* If yes, no match - looking for ABC$(, found ABC$ */
	move.l a1, a6           /* String variable found, step current program location past it */
	move.l a2, d0           /* Get pointer to variable entry */
	addq.l #1, d0
	and.w #0xfffe, d0
	move.l d0, a0           /* Step to next even address */
	moveq #0, d0
	move.b 5(a0), d0        /* String length into D0 */
	move.l a0, a1           /* String pointer pointer into A1 (used if variable is being modified) */
	move.l (a0), a0         /* String address into A0 */
	moveq #-1, d6           /* String type indicator */
	rts
array:
	move.l a1, a6           /* Array variable found, step current program location past it */
	move.l a2, d0           /* Get pointer to variable entry */
	addq.l #1, d0
	and.w #0xfffe, d0
	move.l d0, a0           /* Step to next even address */
	move.w #2, -(a7)        /* Will be loaded into CCR on return - sets V flag */
	move.b -2(a1), d0       /* Get character before ( */
	cmp.b d1, d0
	beq.s arrayint          /* If %, array of integers */
	cmp.b d2, d0
	beq.s arraystr          /* If $, array of strings */
	moveq #1, d6            /* Else array of floats, D6 = float type indicator */
	rtr                     /* Return with V flag set */
arrayint:
	moveq #0, d6            /* D6 = integer type indicator */
	rtr                     /* Return with V flag set */
arraystr:
	moveq #-1, d6           /* D6 = string type indicator */
	rtr                     /* Return with V flag set */

arrayacc:
	move.l a0, a1
	add.w (a0), a1
	move.w (a0)+, d2
	lsr.w #1, d2
	subq.w #2, d2
	moveq #0, d3
	bra.s array1
badsub:
	trap #err
	dc.b 15
.ascii  "Bad subscript"
	dc.b  0
	dc.b  0
.align 2
array0:
	cmp.b #44, (a6)+
	bne.s badsub
array1:
	movem.l a0/a1/a2/d2/d3/d6, -(a7)
	bsr intexpr
	tst.l d0
	bmi.s badsub
	swap d0
	tst.w d0
	bne.s badsub
	swap d0
	movem.l (a7)+, a0/a1/a2/d2/d3/d6
	cmp.w (a0), d0
	bcc.s badsub
	mulu (a0)+, d3
	add.l d0, d3
	dbra d2, array0
	cmp.b #0x29, (a6)+
	bne msngbrkt
	tst.b d6
	beq.s accint
	bmi.s accstr
	moveq #1, d6
	mulu #6, d3
	lea 0(a1, d3.l), a0
	move.w (a0), d1
	move.l 2(a0), d0
	rts
accint:
	asl.l #2, d3
	moveq #0, d6
	lea 0(a1, d3.l), a0
	move.l (a0), d0
	rts
accstr:
	mulu #6, d3
	moveq #-1, d6
	add.l d3, a1
	move.l (a1), a0
	moveq #0, d0
	move.b 5(a1), d0
	rts

/* Deal with a function call */
function:
	sub.b #0xc4, d0
	bcs.s function0
	ext.w d0
	add.w d0, d0
	lea fnjt-.-2(pc), a0
	add.w 0(a0, d0.w), a0
	jmp (a0)
function0:
    bra syntax
fnjt:
	dc.w syntax-fnjt, pagefn-fnjt, topfn-fnjt, lomemfn-fnjt, himemfn-fnjt
	dc.w time-fnjt, chrs-fnjt, gets-fnjt, inkeys-fnjt, lefts-fnjt
	dc.w mids-fnjt, rights-fnjt, strs-fnjt, strings-fnjt
	dc.w instr-fnjt, valfn-fnjt, asc-fnjt, len-fnjt, get-fnjt, inkey-fnjt
	dc.w syntax-fnjt, pos-fnjt, vpos-fnjt, countfn-fnjt, point-fnjt
	dc.w errnum-fnjt, errln-fnjt, opi-fnjt, opo-fnjt, opu-fnjt
	dc.w syntax-fnjt, bget-fnjt, eof-fnjt, true-fnjt, false-fnjt, abs-fnjt
	dc.w acsfn-fnjt, asnfn-fnjt, atnfn-fnjt, cosfn-fnjt, deg-fnjt
	dc.w eval-fnjt, expfn-fnjt, fn-fnjt, intarg-fnjt, lnfn-fnjt, logfn-fnjt
	dc.w not-fnjt, pi-fnjt, rad-fnjt, rnd-fnjt, sgn-fnjt, sinfn-fnjt
	dc.w sqrfn-fnjt, tanfn-fnjt, usrfn-fnjt
	dc.w syntax-fnjt, syntax-fnjt, syntax-fnjt, syntax-fnjt

/* PAGE function */
pagefn:
	move.l page, d0
	moveq #0, d6
	rts

/* TOP function */
topfn:
	move.l top, d0
	moveq #0, d6
	rts

/* LOMEM function */
lomemfn:
	move.l lomem, d0
	moveq #0, d6
	rts

/* HIMEM function */
himemfn:
	move.l himem, d0
	moveq #0, d6
	rts

/* Evaluate an expression and return an integer result */
intexpr:
	bsr expr
	tst.b d6
	bmi typemis
	bne fpint
	rts

/* Evaluate an operand and return an integer result
   Used where simple expressions can be unbracketed but full expressions
   must be bracketed - e.g. CHR$C% or CHR$(C% OR 32)
 */
intarg:
	bsr operand
	lsr.b #1, d6
	bne typemis
	bcs fpint
	rts

/* CHR$ function */
chrs:
	bsr intarg
chrs1:
	lea strbf, a0
	move.b d0, (a0)+
	move.b #13, (a0)
	subq.l #1, a0
	moveq #1, d0
	moveq #-1, d6
	rts

/* GET$ function */
gets:
	trap #rdch
	bcs.s escape
	bra.s chrs1
escape:
	trap #err
	dc.b 17
.ascii  "Escape"
	dc.b  0
.align 2

/* INKEY$ function */
inkeys:
	bsr intarg
	swap d0
	move.w #0x8100, d0
	trap #gen
	swap d0
	tst.b d0
	bgt.s escape
	bmi.s inkeys1
	rol.l #8, d0
	bra.s chrs1
inkeys1:
	lea strbf, a0
	move.b #13, (a0)
	moveq #0, d0
	moveq #-1, d6
	rts

/* If a string is in the general string buffer, copy it to the BASIC stack.
   If it is elsewhere, leave it where it is.
 */
pstbf:
	lea strbf, a4
	cmp.l a4, a0
	bne.s ntstbf
	move.w d0, d1
	addq.w #3, d1
	bsr chkstk
	move.l a5, a4
	move.w d0, d1
	st (a4)+
	move.b d0, (a4)+
	lsr.w #1, d1
pstbf1:
	move.w (a0)+, (a4)+
	dbra d1, pstbf1
	lea 2(a5), a0
ntstbf:
	rts

/* LEFT$ function */
lefts:
	bsr strexpr
	move.l a5, a1
	bsr.s pstbf
	movem.l a1/a0/d0, -(a7)
	cmp.b #44, (a6)+
	bne.s msngcm
	bsr intexpr
	cmp.b #0x29, (a6)+
	bne msngbrkt
	move.l d0, d1
	movem.l (a7)+, a5/a0/d0
	cmp.l d1, d0
	bcc.s lefts0
	move.l d0, d1
lefts0:
	move.l d1, d0
	lea strbf, a1
	bra.s lefts1
lefts2:
	move.b (a0)+, (a1)+
lefts1:
	dbra d1, lefts2
	move.b #13, (a1)
	lea strbf, a0
	moveq #-1, d6
	rts
msngcm:
	trap #err
	dc.b 5
.ascii  "Missing ,"
	dc.b  0
	dc.b  0
.align 2

/* MID$ function */
mids:
	bsr strexpr
	move.l a5, a1
	bsr pstbf
	movem.l a1/a0/d0, -(a7)
	cmp.b #44, (a6)+
	bne.s msngcm
	bsr intexpr
	move.l d0, -(a7)
	cmp.b #44, (a6)
	bne.s mids1
	addq.l #1, a6
	bsr intexpr
	bra.s mids2
mids1:
	moveq #0, d0
	subq.b #1, d0
mids2:
	cmp.b #0x29, (a6)+
	bne msngbrkt
	move.l d0, d2
	move.l (a7)+, d1
	movem.l (a7)+, d0/a0/a5
	tst.l d2
	beq inkeys1
	subq.l #1, d1
	sub.l d1, d0
	bls inkeys1
	cmp.l d2, d0
	bcc.s mids3
	move.l d0, d2
mids3:
	move.l d2, d0
	lea 0(a0, d1.w), a1
	lea strbf, a0
	subq.w #1, d2
mids4:
	move.b (a1)+, (a0)+
	dbra d2, mids4
	move.b #13, (a0)
	lea strbf, a0
	moveq #-1, d6
	rts

/* RIGHT$ function */
rights:
	bsr strexpr
	move.l a5, a1
	bsr pstbf
	cmp.b #0x2c, (a6)+
	bne msngcm
	movem.l a1/a0/d0, -(a7)
	bsr intexpr
	cmp.b #0x29, (a6)+
	bne msngbrkt
	move.l d0, d1
	movem.l (a7)+, a0/d0/a5
	moveq #-1, d6
	cmp.l d1, d0
	bcc.s rights0
	move.l d0, d1
rights0:
	sub.l d1, d0
	add.w d0, a0
	move.l d1, d0
	lea strbf, a1
rights2:
	move.b (a0)+, (a1)+
	dbra d1, rights2
	lea strbf, a0
	rts

/* STR$~ convert number to hex string */
strshex:
	addq.l #1, a6
	bsr intarg
hexasc:
	st -(a7)
hexasc1:
	moveq #15, d1
	and.b d0, d1
	cmp.b #9, d1
	bls.s hexasc0
	addq.b #7, d1
hexasc0:
	add.b #48, d1
	move.b d1, -(a7)
	lsr.l #4, d0
	bne.s hexasc1
	lea strbf, a0
hexasc2:
	move.b (a7)+, (a0)+
	bpl.s hexasc2
	move.b #13, -(a0)
	move.l a0, d0
	lea strbf, a0
	sub.l a0, d0
	moveq #-1, d6
	rts

/* STR$ function */
strs:
	cmp.b #0x7e, (a6)
	beq.s strshex
	bsr operand
	tst.b d6
	bmi typemis
	beq.s strsint
	lea strbf, a0
	moveq #1, d6
	bsr fpasc
strs2:
	move.l a0, d0
	lea strbf, a0
	sub.l a0, d0
	subq.l #1, d0
	moveq #-1, d6
	rts
strsint:
	lea strbf, a0
	bsr.s intasc
	bra.s strs2
intasc:
	tst.l d0
	bpl.s intasc1
	move.b #45, (a0)+
	neg.l d0
intasc1:
	clr.b -(a7)
intasc2:
	bsr.s divby10
	add.b #48, d1
	move.b d1, -(a7)
	tst.l d0
	bne.s intasc2
intasc3:
	move.b (a7)+, (a0)+
	bne.s intasc3
	move.b #13, -1(a0)
	rts
divby10:
	move.w d0, d2
	clr.w d0
	swap d0
	divu #10, d0
	move.w d0, d1
	move.w d2, d0
	divu #10, d0
	swap d1
	move.w d0, d1
	clr.w d0
	swap d0
	exg d0, d1
	rts
illegal:
	trap #err
	dc.b 52
.ascii  "Illegal quantity"
	dc.b  0
.align 2

/* STRING$ function */
strings:
	bsr strexpr
	move.l a5, a1
	bsr pstbf
	cmp.b #0x2c, (a6)+
	bne msngcm
	movem.l a1/a0/d0, -(a7)
	bsr intexpr
	cmp.b #0x29, (a6)+
	bne msngbrkt
	move.l d0, d1
	bmi.s illegal
	movem.l (a7)+, d0/a0/a5
	tst.l d0
	beq inkeys1
	swap d1
	beq inkeys1
	tst.w d1
	bne strlong
	swap d1
	move.w d0, d2
	mulu d1, d0
	cmp.l #255, d0
	bhi strlong
	subq.w #1, d2
	lea strbf, a1
	subq.w #1, d1
strings1:
	move.l a0, a2
	move.w d2, d3
strings2:
	move.b (a2)+, (a1)+
	dbra d3, strings2
	dbra d1, strings1
	move.b #13, (a1)
	lea strbf, a0
	moveq #-1, d6
	rts

/* INSTR function */
instr:
	bsr strexpr
	move.l a5, a1
	bsr pstbf
	cmp.b #0x2c, (a6)+
	bne msngcm
	movem.l a1/a0/d0, -(a7)
	bsr strexpr
	cmp.b #0x2c, (a6)
	bne.s instr1a
	addq.l #1, a6
	bsr pstbf
	movem.l a0/d0, -(a7)
	bsr intexpr
	bra.s instr1
instr1a:
	movem.l a0/d0, -(a7)
	moveq #1, d0
instr1:
	cmp.b #0x29, (a6)+
	bne msngbrkt
	move.l d0, d2
	movem.l (a7)+, a1/d1
	movem.l (a7)+, a0/d0/a5
	tst.l d1
	beq.s instr0a
	subq.l #1, d2
	bge.s instr2
	moveq #0, d2
instr2:
	sub.l d1, d0
	sub.l d2, d0
	bcs.s false
	add.w d2, a0
	subq.w #1, d1
instr3:
	addq.w #1, d2
	move.l a0, a2
	move.l a1, a3
	move.w d1, d3
instr4:
	cmpm.b (a2)+, (a3)+
	dbne d3, instr4
	beq.s instr0a
	addq.l #1, a0
	dbra d0, instr3
false:
	moveq #0, d2
instr0a:
	move.l d2, d0
	moveq #0, d6
	rts

/* VAL function */
valfn:
	bsr operand
	tst.b d6
	bpl typemis
val2:
	moveq #0, d6
	tst.l d0
	beq.s val0
	move.l a6, -(a7)
	move.l a0, a6
val3:
	move.b (a6)+, d0
	cmp.b #32, d0
	beq.s val3
	cmp.b #45, d0
	seq -(a7)
	beq.s val1
	cmp.b #43, d0
	beq.s val1
	subq.l #1, a6
val1:
	bsr number4
	tst.b (a7)+
	bpl.s val4
	bsr negnum
val4:
	move.l (a7)+, a6
val0:
	rts

/* ASC function */
asc:
	bsr operand
	tst.b d6
	bpl typemis
	moveq #0, d6
	tst.l d0
	beq.s asc0
	move.b (a0), d0
	rts
asc0:
	moveq #-1, d0
	rts

/* LEN function */
len:
	bsr operand
	tst.b d6
	bpl typemis
	moveq #0, d6
	rts

/* GET function */
get:
	trap #rdch
	bcs escape
	and.l #0xff, d0
	moveq #0, d6
	rts

/* INKEY function */
inkey:
	bsr intarg
	move.w d0, -(a7)
	swap d0
	move.w #0x8100, d0
	trap #gen
	tst.w (a7)+
	bmi.s inkeyneg
	swap d0
	tst.b d0
	bgt escape
	bmi.s true
	rol.l #8, d0
	and.l #0xff, d0
	moveq #0, d6
	rts

/* TRUE function */
true:
	moveq #-1, d0
	moveq #0, d6
	rts

inkeyneg:
	swap d0
	ext.w d0
	ext.l d0
	moveq #0, d6
	rts

/* POS function */
pos:
	move.w #0x8600, d0
	trap #gen
	lsr.w #8, d0
	ext.l d0
	moveq #0, d6
	rts

/* VPOS function */
vpos:
	move.w #0x8600, d0
	trap #gen
	swap d0
	ext.w d0
	ext.l d0
	moveq #0, d6
	rts

/* COUNT function */
countfn:
	moveq #0, d0
	moveq #0, d6
	move.w prtct, d0
	rts

/* POINT function */
point:
	bsr intexpr
	clr.l -(a7)
	rol.w #8, d0
	move.w d0, -(a7)
	cmp.b #44, (a6)+
	bne msngcm
	bsr intexpr
	cmp.b #41, (a6)+
	bne msngbrkt
	rol.w #8, d0
	move.w d0, 2(a7)
	move.l a7, a1
	lea HOST_SIDE_BUF, a0
	move.l #0x50003, d0
	trap #gen
	move.l #0x5f00901, d0
	trap #gen
	move.l a7, a1
	lea 0x5f0, a0
	move.l #0x50002, d0
	trap #gen
	move.b 4(a7), d0
	ext.w d0
	ext.l d0
	moveq #0, d6
	addq.l #6, a7
	rts

/* ERRNUM function */
errnum:
	moveq #0x10, d0
	trap #gen
	and.l #0xff, d0
	moveq #0, d6
	rts

/* ERRLN function */
errln:
	moveq #0, d0
	move.w erl, d0
	moveq #0, d6
	rts

/* OPENIN, OPENOUT, OPENUP all the same on cassette */
.equ	opi, .
.equ	opo, .
.equ	opu, .
	move.b -1(a6), d0
	sub.b #0xda, d0
	move.b d0, -(a7)
	bsr operand
	tst.b d6
	bpl typemis
	move.b (a7)+, d0
	trap #file
	and.l #0xff, d0
	moveq #0, d6
	rts

/* BGET function */
bget:
	bsr intarg
	asl.w #8, d0
	move.b #2, d0
	trap #file
	and.l #0xff, d0
	moveq #0, d6
	rts

/* EOF function */
eof:
	bsr intarg
	asl.w #8, d0
	move.b #8, d0
	trap #file
	scs d0
	ext.w d0
	ext.l d0
	moveq #0, d6
	rts

/* ABS function */
abs:
	bsr operand
	tst.b d6
	bmi typemis
	beq.s absint
	and.w #0xff, d1
	rts
absint:
	tst.l d0
	bpl.s absint0
	neg.l d0
	bvs ovfw
absint0:
	rts

/* RAD function */
rad:
	bsr.s fparg
	move.w #0x7b, d3
	move.l #0x8efa3513, d2
	bra.s deg1

/* DEG function */
deg:
	bsr.s fparg
	move.w #0x86, d3
	move.l #0xe52ee0d3, d2
deg1:
	bsr fpmul
	moveq #1, d6
	rts

/* SQR function */
sqrfn:
	bsr.s fparg
	bsr sqr
	moveq #1, d6
	rts

/* Evaluate an operand and return a floating point result
   Used where simple expressions can be unbracketed but full expressions
   must be bracketed - e.g. SQR2 or SQR(X*X+Y*Y)
 */
fparg:
	bsr operand
	tst.b d6
	bmi typemis
	beq intfp
	rts

/* ACS function */
acsfn:
	bsr.s fparg
	bsr acs
	moveq #1, d6
	rts

/* ASN function */
asnfn:
	bsr.s fparg
	bsr asn
	moveq #1, d6
	rts

/* ATN function */
atnfn:
	bsr.s fparg
	bsr atn
	moveq #1, d6
	rts

/* SIN function */
sinfn:
	bsr.s fparg
	bsr sin
	moveq #1, d6
	rts

/* COS function */
cosfn:
	bsr.s fparg
	bsr cos
	moveq #1, d6
	rts

/* TAN function */
tanfn:
	bsr.s fparg
	bsr tan
	moveq #1, d6
	rts

/* EXP function */
expfn:
	bsr.s fparg
	bsr exp
	moveq #1, d6
	rts

/* LN function */
lnfn:
	bsr.s fparg
	bsr ln
	moveq #1, d6
	rts

/* LOG function */
logfn:
	bsr.s fparg
	bsr log
	moveq #1, d6
	rts

/* PI function */
pi:
	move.w #0x82, d1
	move.l #0xc90fdaa2, d0
	moveq #1, d6
	rts

/* EVAL function */
eval:
	bsr operand
	tst.b d6
	bpl typemis
	movem.l a5/a6, -(a7)    /* Save program pointer and BASIC stack pointer */
    bsr crunchstr           /* Move string to strbf and tokenize */
	bsr pstbf               /* Move tokenized string to BASIC stack */
	move.l a0, a6           /* Program pointer points to tokenized string */
	bsr expr                /* Evaluate it as an expression */
	movem.l (a7)+, a5/a6    /* Restore program pointer and BASIC stack pointer */
	rts

/* Tokenize a string
   Enter with A0 pointing to string
              D0.W = length of string
   Return with A0 pointing to strbf, which contains the tokenized string
               D0.L = length of tokenized string
 */
crunchstr:
	lea strbf, a1
	cmp.l a1, a0
	beq.s crunchstr1
crunchstr2:
	move.b (a0)+, (a1)+     /* If not already in string buffer, copy it there */
	dbra d0, crunchstr2
crunchstr1:
	lea strbf, a6           /* pointer to line to be tokenized */
	bsr crunch              /* tokenize it */
	lea strbf, a0           /* A0 points to string buffer */
	move.l a0, a1
	moveq #13, d0
	moveq #-1, d1
crunchstr3:
	cmp.b (a1), d1          /* Check for FF (cache space reservation token) */
	beq.s crunchstr4        /* branch out if it is */
	cmp.b (a1)+, d0         /* Check for CR (end of string) */
	bne.s crunchstr3        /* If not, check next char */
	move.l a1, d0           /* pointer to byte after CR */
	sub.l a0, d0            /* D0.L = length including CR */
	subq.l #1, d0           /* subtract 1 for CR */
	rts
crunchstr4:
	move.l a1, d2           /* FF token */
	addq.l #8, d2           /* Add space for 6 bytes after FF, aligned to even address */
	and.w #0xfffe, d2
	move.l d2, a1
	bra.s crunchstr3        /* check next char */

/* NOT function */
not:
	bsr intarg
	not.l d0
	moveq #0, d6
	rts

/* RND function
 * Pseudo random number generator uses algorithm
 *  x_n+1 = 69069 * x_n + 41
 *
 * All values are 32 bit and arithmetic is modulo 2^32
 */
rnd:
	cmp.b #40, (a6)
	beq.s rnd2
rnd1:
	move.w #0xdcd, d0
	move.w d0, d1
	mulu rndv, d0
	add.w rndv+2, d0
	mulu rndv+2, d1
	swap d0
	move.w #41, d0
	add.l d1, d0
	move.l d0, rndv
	moveq #0, d6
	rts
rnd2:
	addq.l #1, a6
	bsr intexpr
	cmp.b #41, (a6)+
	bne msngbrkt
	tst.l d0
	bpl.s rnd3
	move.l d0, rndv
	moveq #0, d6
	rts
rnd3:
	bsr.s rnd1
	tst.l d0
	bpl.s rnd4
	move.w #0x80, d1
	moveq #1, d6
	rts
rnd4:
	bsr intfp
	sub.b #32, d1
	moveq #1, d6
	rts

/* SGN function */
sgn:
	bsr operand
	tst.b d6
	bmi typemis
	bne.s sgnfp
	tst.l d0
	beq.s sgn0
sgn1:
	smi d0
	or.b #1, d0
	ext.w d0
	ext.l d0
sgn0:
	moveq #0, d6
	rts
sgnfp:
	tst.b d1
	beq false
	tst.w d1
	bra.s sgn1

/* USR function */
usrfn:
	bsr intarg
	move.l d0, a0
	jmp (a0)

/* Evaluate an expression and check for a string result */
strexpr:
	bsr expr
	tst.b d6
	bpl typemis
	rts

/* Evaluate an expression and check for a numeric result */
numexpr:
	bsr expr
	tst.b d6
	bmi typemis
	rts

/* Allocate space on the BASIC stack, checking for out of memory */
chkstk:
	addq.l #1, d1
	and.b #0xfe, d1
	move.l a5, a4
	sub.w d1, a5
	cmp.l vartop, a5
	bcs.s stkovfw
	rts
stkovfw:
	trap #err
	dc.b 35
.ascii  "Stack overflow"
	dc.b  0
.align 2

/* TIME function */
time:
	move.l #0x05f00101, d0
	trap #gen
	clr.l -(a7)
	move.l a7, a1
	move.w #0x5f0, a0
	move.l #0x00040002, d0
	trap #gen
	move.l (a7)+, d0
	rol.w #8, d0
	swap d0
	rol.w #8, d0
	moveq #0, d6
	rts


/* Evaluate a complete expression
 * An expression consists of one or more operands, with an operator
 * between each pair of successive operands.
 * The operators are applied in an order which is determined by their
 * precedence, as follows (highest to lowest)
 *
 *      Binary ? and !
 *      ^
 *      * / DIV MOD
 *      + -
 *      < = > <= >= <>
 *      AND
 *      OR  EOR
 *
 * Operators with same precedence are evaluated left to right.
 */
expr:
	clr.w -(a5)                 /* Push precedence value of 0 to BASIC stack to start with */
	cmp.l vartop, a5
	bcs stkovfw
expr1:
	bsr operand                 /* Evaluate next operand */
	moveq #0, d5                /* Clear top 24 bits of D5 */
expr1a:
	move.b (a6)+, d5            /* Get next operator, if any */
	cmp.b #32, d5               /* skip spaces */
	beq.s expr1a
	lea optab-.-2(pc), a4       /* Operator lookup table */
	move.b 0(a4, d5.w), d3      /* Get operator number */
	bmi exprend                 /* If not a valid operator, finish up evaluation and return */
	ext.w d3
	lea oppr-.-2(pc), a4        /* Operator precedence value table */
	move.b 0(a4, d3.w), d4      /* Get precedence value for this operator */
expr0b:
	cmp.b (a5), d4              /* Compare against precedence of last stacked operator */
	bls exprdo                  /* If current operator has lower precedence, evaluate the stacked operator */
	tst.b d6
	bmi.s expr2                 /* branch if string result */
	bne.s expr3                 /* branch if float result */
	move.l a5, a4
	sub.w #12, a5               /* Reserve 12 bytes on BASIC stack, checking for overflow */
	cmp.l vartop, a5
	bcs stkovfw
	move.l d0, -(a4)            /* Save operand value */
	bra.s expr4
expr3:
	move.l a5, a4               /* float value - reserve 14 bytes on BASIC stack */
	sub.w #14, a5
	cmp.l vartop, a5
	bcs stkovfw
	move.l d0, -(a4)            /* save operand mantissa */
	move.w d1, -(a4)            /* save operand sign/exponent */
	bra.s expr4
expr2:
	move.l d0, d1               /* string operand value */
	addq.w #8, d1               /* reserve 8 + string length bytes on BASIC stack */
	bsr chkstk
	move.l a0, a1
	lea 6(a5), a2
	move.l a2, a4               /* set A4 correctly for later use */
	move.b d6, (a2)+            /* push operand type */
	move.b d0, (a2)+            /* push string length */
	addq.w #1, d0               /* convert length to words, rounding up */
	lsr.w #1, d0
	bra.s expr2b
expr2a:
	move.w (a1)+, (a2)+         /* Copy string to BASIC stack */
expr2b:
	dbra d0, expr2a
	bra.s expr5                 /* Skip push of operand type, push operator address and precedence and continue */
expr4:
	st -(a4)                    /* push FF onto BASIC stack */
	move.b d6, -(a4)            /* push operand type onto BASIC stack */
expr5:
	add.w d3, d3
	lea opjt-.-2(pc), a0        /* Operator jump table */
	add.w 0(a0, d3.w), a0       /* Entry for operator being pushed */
	move.l a0, -(a4)            /* Push operator call address */
	clr.b -(a4)                 /* Push 0 byte */
	move.b d4, -(a4)            /* Push operator precedence value */
	bra expr1                   /* Loop around to fetch next operand */

/* current operator has lower precedence than last stacked one */
exprdo:
	movem.w d4/d3, -(a7)        /* save operator number and precedence */
	addq.l #2, a5               /* pop precedence off BASIC stack */
	move.l (a5)+, a4            /* pop operator call address */
	jsr (a4)                    /* call the operator (first operand on stack, second in D6/D0/D1) */
                                /* result returned in D6/D0/D1 */
	movem.w (a7)+, d3/d4        /* restore operator number and precedence */
	bra expr0b                  /* Go back to compare precedence with next stacked operator */

/* Have reached end of expression */
exprend:
	tst.w (a5)+                 /* Pop last precedence value off BASIC stack */
	beq.s exprend1              /* If zero, we are finished */
	move.l (a5)+, a4            /* Pop operator call address */
	jsr (a4)                    /* Call the operator */
	bra.s exprend               /* Repeat until all stacked operators have been evaluated */
exprend1:
	subq.l #1, a6               /* Move program pointer back to character which terminated the expression */
	rts
optab:
	dc.l -1, -1, -1, -1, -1, -1, -1, -1     /* 00 - 1F */
	dc.b -1     /* 20 */
	dc.b  17    /* 21 = ! */
	dc.b  -1
	dc.b  -1
	dc.b  -1
	dc.b  -1
	dc.b  -1
	dc.b  -1
	dc.b  -1
	dc.b  -1
	dc.b  2     /* 2A = * */
	dc.b  0     /* 2B = + */
	dc.b  -1
	dc.b  1     /* 2D = - */
	dc.b  -1
	dc.b  3     /* 2F = / */
	dc.b -1
	dc.b  -1
	dc.b  -1
	dc.b  -1
	dc.b  -1
	dc.b  -1
	dc.b  -1
	dc.b  -1
	dc.b  -1
	dc.b  -1
	dc.b  -1
	dc.b  -1
	dc.b  7     /* 3C = < */
	dc.b  8     /* 3D = = */
	dc.b  9     /* 3E = > */
	dc.b  16    /* 3F = ? */
	dc.l -1, -1, -1, -1, -1, -1, -1     /* 40 - 5B */
    dc.b  -1
    dc.b  -1
    dc.b  6     /* 5E = ^ */
    dc.b  -1
    dc.l -1, -1, -1, -1, -1, -1, -1, -1 /* 60 - 7F */
	dc.l -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1     /* 80 - BB */
	dc.b  13    /* BC = AND token */
	dc.b  14    /* BD = OR token */
	dc.b  15    /* BE = EOR token */
	dc.b  5     /* BF = DIV token */
	dc.b  4     /* C0 = MOD token */
	dc.b  10    /* C1 = <= token */
	dc.b  12    /* C2 = <> token */
	dc.b  11    /* C3 = >= token */
	dc.l -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1     /* C4 - FF */
oppr:
	dc.b  0x70      /* + */
	dc.b  0x70      /* - */
	dc.b  0x78      /* * */
	dc.b  0x78      /* / */
	dc.b  0x78      /* MOD */
	dc.b  0x78      /* DIV */
	dc.b  0x7c      /* ^ */
	dc.b  0x60      /* < */
	dc.b  0x60      /* = */
	dc.b  0x60      /* > */
	dc.b  0x60      /* <= */
	dc.b  0x60      /* >= */
	dc.b  0x60      /* <> */
	dc.b  0x58      /* AND */
	dc.b  0x50      /* OR */
	dc.b  0x50      /* EOR */
	dc.b  0x7e      /* ? */
	dc.b  0x7e      /* ! */
.align 2
opjt:
	dc.w add-opjt, sub-opjt, mul-opjt, div-opjt, mod-opjt, intdiv-opjt
	dc.w pwrop-opjt, lt-opjt, eq-opjt, gt-opjt, le-opjt, ge-opjt, ne-opjt
	dc.w and-opjt, or-opjt, xor-opjt, peekop-opjt, qeekop-opjt

/* Check that both operands are strings or both are numeric */
chktp:
	move.b (a5), d4
	eor.b d6, d4
	bmi typemis
	tst.b d6
	rts

/* Check that both operands are numeric */
chkn:
	tst.b (a5)
	bmi typemis
	tst.b d6
	bmi typemis
	rts

/* Execute the addition operator */
add:
	bsr.s chktp         /* check two operands are both numeric or both string */
	bmi.s concat        /* if string, do concatenation */
	move.b d6, d5
	or.b (a5), d5
	bne.s addfp         /* if either is floating, do float addition */
	add.l 2(a5), d0     /* otherwise do integer addition */
	bvc.s add0          /* if no integer overflow, finish and return integer result */
	sub.l 2(a5), d0     /* if integer overflow, treat as float */

/* Add floats */
addfp:
	bsr getfp
	bsr fpadd
	moveq #1, d6
	rts

add0:
	addq.l #6, a5       /* pop integer off BASIC stack */
	rts

/* String concatenation */
concat:
	moveq #0, d1
	move.b 1(a5), d1
	addq.l #2, a5
	lea strbf, a1
	move.w d0, d2
	add.b d1, d0
	bcs strlong
	lea 1(a1, d0.w), a1
	lea 1(a0, d2.w), a0
concat1:
	move.b -(a0), -(a1)
	dbra d2, concat1
	lea strbf, a1
	bra.s concat3
concat2:
	move.b (a5)+, (a1)+
concat3:
	dbra d1, concat2
	lea strbf, a0
	move.l a5, d5
	addq.l #1, d5
	and.b #0xfe, d5
	move.l d5, a5
	moveq #-1, d6
	rts

/* Execution the subtraction operator */
sub:
	bsr chkn
	move.b d6, d5
	or.b (a5), d5
	bne.s subfp
	move.l d0, d1
	move.l 2(a5), d0
	sub.l d1, d0
	bvc add0
	move.l d1, d0
subfp:
	bsr.s getfp
	bsr fpsub
	moveq #1, d6
	rts

/* Convert operands to float */
getfp:
	tst.b d6
	bne.s getfp1
	bsr intfp
getfp1:
	move.l d0, d2
	move.w d1, d3
	bsr.s getnum
	tst.b d6
	beq intfp
	rts

/* Pop a numeric operand off the BASIC stack */
getnum:
	move.b (a5)+, d6
	addq.l #1, a5
	beq.s gtnm1
	move.w (a5)+, d1
gtnm1:
	move.l (a5)+, d0
	rts

/* Execute multiplication operator */
mul:
	bsr chkn
	move.b d6, d5
	or.b (a5), d5
	bne.s mulfp
	move.l 2(a5), d5
	eor.l d0, d5
	move.l 2(a5), d2
	bpl.s mul1
	neg.l d2
mul1:
	tst.l d0
	bpl.s mul2
	neg.l d0
mul2:
	cmp.l #0x10000, d2
	bcs.s mul3
	cmp.l #0x10000, d0
	bcc.s mulfp
	move.w d0, d3
	bra.s mul4
mul3:
	move.w d2, d3
	move.l d0, d2
mul4:
	move.w d2, d4
	swap d2
	mulu d3, d2
	cmp.l #0x8000, d2
	bcc.s mulfp
	swap d2
	mulu d3, d4
	add.l d4, d2
	bvs.s mulfp
	addq.l #6, a5
	move.l d2, d0
	tst.l d5
	bpl.s mul5
	neg.l d0
mul5:
	rts
mulfp:
	bsr getfp
	bsr fpmul
	moveq #1, d6
	rts

/* Execute division operator */
div:
	bsr chkn
	bsr getfp
	bsr fpdiv
	moveq #1, d6
	rts
getint:
	bsr chkn
	beq.s getint1
	bsr fpint
getint1:
	move.l d0, d2
	bsr getnum
	lsr.b #1, d6
	bcs fpint
	rts

/* Execute modulo operator */
mod:
	bsr getint

/* Integer division or modulo */
divint:
	move.l d2, d5
	beq divby0
	eor.l d0, d5
	tst.l d0
	smi d5
	bpl.s divint1
	neg.l d0
divint1:
	tst.l d2
	bpl.s divint2
	neg.l d2
divint2:
	cmp.l #0x10000, d2
	bcc.s divint3
	move.w d0, d1
	clr.w d0
	swap d0
	divu d2, d0
	move.w d0, d3
	move.w d1, d0
	divu d2, d0
	swap d3
	move.w d0, d3
	clr.w d0
	swap d0
divint6:
	tst.l d5
	bpl.s divint2a
	neg.l d3
	bvs ovfw
divint2a:
	tst.b d5
	beq.s divint2b
	sub.l d2, d0
	neg.l d0
divint2b:
	rts
divint3:
	move.w d0, d3
	swap d3
	clr.w d3
	clr.w d0
	swap d0
	moveq #15, d1
divint4:
	add.l d3, d3
	addx.l d0, d0
	cmp.l  d2, d0
	bcs.s divint5
	sub.l d2, d0
	addq.b #1, d3
divint5:
	dbra d1, divint4
	bra.s divint6

/* Execute integer division operator */
intdiv:
	bsr getint
	bsr divint
	move.l d3, d0
	rts

/* Execute AND operator */
and:
	bsr getint
	and.l d2, d0
	rts

/* Execute OR operator */
or:
	bsr getint
	or.l d2, d0
	rts

/* Execute EOR operator */
xor:
	bsr getint
	eor.l d2, d0
	rts

/* Execute binary ? operator */
peekop:
	bsr getint
	move.l d0, a0
	add.l d2, a0
	moveq #0, d0
	move.b (a0), d0
	rts

/* Execute binary ! operator */
qeekop:
	bsr getint
	add.l d2, d0
	btst #0, d0
	bne aerr
	move.l d0, a0
	move.l (a0), d0
	rts

/* Execute exponentiation operator */
pwrop:
	bsr chkn
	beq.s intpwr
pwrfp:
	bsr getfp
	bsr power
	moveq #1, d6
	rts
intpwr0:
	moveq #1, d0
	moveq #0, d6
	tst.b (a5)
	addq.l #6, a5
	beq.s intpwr0a
	addq.l #2, a5
intpwr0a:
	rts
intpwr:
	tst.l d0
	beq.s intpwr0
	moveq #32, d2
	cmp.l d2, d0
	bge.s pwrfp
	moveq #-32, d2
	cmp.l d2, d0
	ble.s pwrfp
	tst.b (a5)
	addq.l #2, a5
	beq.s intpwr1
	move.w (a5)+, d3
	move.l (a5)+, d2
	bra.s intpwr2
intpwr1:
	move.l d0, d2
	move.l (a5)+, d0
	bsr intfp
	exg d0, d2
	move.w d1, d3
intpwr2:
	move.b d0, d6
	move.l d2, d0
	move.w d3, d1
	tst.b d6
	bpl.s intpwr3
	neg.b d6
	move.w #0x81, d1
	move.l #0x80000000, d0
	bsr fpdiv
intpwr3:
	move.l d0, -(a7)
	move.w d1, -(a7)
	bra.s intpwr5
intpwr4:
	move.w (a7), d3
	move.l 2(a7), d2
	bsr fpmul
intpwr5:
	subq.b #1, d6
	bne.s intpwr4
	addq.l #6, a7
	moveq #1, d6
	rts

/* Execute = operator */
eq:
	bsr.s cmp
	tst.b d0
	seq d0
	bra.s ex

/* Execute <> operator */
ne:
	bsr.s cmp
	tst.b d0
	sne d0
	bra.s ex

/* Execute <= operator */
le:
	bsr.s cmp
	tst.b d0
	sle d0
	bra.s ex

/* Execute >= operator */
ge:
	bsr.s cmp
	tst.b d0
	sge d0
	bra.s ex

/* Execute < operator */
lt:
	bsr.s cmp
	tst.b d0
	slt d0
	bra.s ex

/* Execute > operator */
gt:
	bsr.s cmp
	tst.b d0
	sgt d0

/* Extend signed byte to 32 bit integer */
ex:
	ext.w d0
	ext.l d0
	moveq #0, d6
	rts

/* Execute a comparison operator */
cmp:
	bsr chktp
	bmi.s cmps
	move.b d6, d5
	or.b (a5), d5
	bne.s cmpfp
	addq.l #2, a5
	move.l (a5)+, d2
	cmp.l d2, d0
	beq false
	sgt d0
	or.b #1, d0
	rts
cmpfp:
	bsr getfp
fpcmp:
	ext.l d1
	and.w #0xff, d1
	bne.s fpcmp1a
	moveq #0, d0
fpcmp1a:
	tst.l d1
	bpl.s fpcmp1
	neg.w d1
fpcmp1:
	ext.l d3
	and.w #0xff, d3
	bne.s fpcmp2a
	moveq #0, d2
fpcmp2a:
	tst.l d3
	bpl.s fpcmp2
	neg.w d3
fpcmp2:
	cmp.w d3, d1
	bne.s fpcmp3
	cmp.l d2, d0
	beq.s fpcmp0
	scs d0
	tst.w d1
	bpl.s fpcmp4
	not.b d0
fpcmp4:
	or.b #1, d0
	rts
fpcmp0:
	moveq #0, d0
	rts
fpcmp3:
	slt d0
	or.b #1, d0
	rts
cmps:
	moveq #0, d1
	move.b 1(a5), d1
	addq.l #2, a5
	move.l a5, a1
	add.w d1, a5
	move.l a5, d2
	addq.l #1, d2
	and.b #0xfe, d2
	move.l d2, a5
	moveq #0, d2
	cmp.b d1, d0
	beq.s cmps1
	shi d2
	bhi.s cmps2
	move.b d0, d1
cmps2:
	or.b #1, d2
cmps1:
	moveq #0, d0
	bra.s cmps4
cmps3:
	cmpm.b (a1)+, (a0)+
cmps4:
	dbne d1, cmps3
	beq.s cmps5
	shi d2
	or.b #1, d2
cmps5:
	move.b d2, d0
	rts

/* Keyword table
 * Each keyword is stored with bit 7 of the last character set
 * Table is in order of the token value assigned to each keyword
 * The first keyword has token value $80
 */
kwdt:
/* TOKEN $80 */
.ascii "AUT"
	dc.b  0xcf
/* TOKEN $81 */
.ascii "BPUT"
	dc.b  0xa3
/* TOKEN $82 */
.ascii  "COLOU"
	dc.b  0xd2
/* TOKEN $83 */
.ascii  "CLEA"
	dc.b  0xd2
/* TOKEN $84 */
.ascii "CLOSE"
	dc.b  0xa3
/* TOKEN $85 */
.ascii "CL"
	dc.b  0xd3
/* TOKEN $86 */
.ascii  "CL"
	dc.b  0xc7
/* TOKEN $87 */
.ascii "CAL"
	dc.b  0xcc
/* TOKEN $88 */
.ascii "CHAI"
	dc.b  0xce
/* TOKEN $89 */
.ascii  "DELET"
	dc.b  0xc5
/* TOKEN $8A */
.ascii  "DRA"
	dc.b  0xd7
/* TOKEN $8B */
.ascii  "DAT"
	dc.b  0xc1
/* TOKEN $8C */
.ascii  "DE"
	dc.b  0xc6
/* TOKEN $8D */
.ascii "DI"
	dc.b  0xcd
/* TOKEN $8E */
.ascii  "ENVELOP"
	dc.b  0xc5
/* TOKEN $8F */
.ascii  "ENDPRO"
	dc.b  0xc3
/* TOKEN $90 */
.ascii "EN"
	dc.b  0xc4
/* TOKEN $91 */
.ascii  "ELS"
	dc.b  0xc5
/* TOKEN $92 */
.ascii  "ERRO"
	dc.b  0xd2
/* TOKEN $93 */
.ascii "FO"
	dc.b  0xd2
/* TOKEN $94 */
.ascii  "GOT"
	dc.b  0xcf
/* TOKEN $95 */
.ascii  "GOSU"
	dc.b  0xc2
/* TOKEN $96 */
.ascii "GCO"
	dc.b  0xcc
/* TOKEN $97 */
.ascii  "INPU"
	dc.b  0xd4
/* TOKEN $98 */
.ascii  "I"
	dc.b  0xc6
/* TOKEN $99 */
.ascii  "LIS"
	dc.b  0xd4
/* TOKEN $9A */
.ascii  "LOA"
	dc.b  0xc4
/* TOKEN $9B */
.ascii  "LOCA"
	dc.b  0xcc
/* TOKEN $9C */
.ascii "LE"
	dc.b  0xd4
/* TOKEN $9D */
.ascii  "LIN"
	dc.b  0xc5
/* TOKEN $9E */
.ascii  "MOD"
	dc.b  0xc5
/* TOKEN $9F */
.ascii  "MOV"
	dc.b  0xc5
/* TOKEN $A0 */
.ascii  "NEX"
	dc.b  0xd4
/* TOKEN $A1 */
.ascii  "NE"
	dc.b  0xd7
/* TOKEN $A2 */
.ascii "OL"
	dc.b  0xc4
/* TOKEN $A3 */
.ascii  "O"
	dc.b  0xce
/* TOKEN $A4 */
.ascii  "OF"
	dc.b  0xc6
/* TOKEN $A5 */
.ascii  "OSCL"
	dc.b  0xc9
/* TOKEN $A6 */
.ascii  "PRIN"
	dc.b  0xd4
/* TOKEN $A7 */
.ascii "PRO"
	dc.b  0xc3
/* TOKEN $A8 */
.ascii  "PLO"
	dc.b  0xd4
/* TOKEN $A9 */
.ascii  "REPEA"
	dc.b  0xd4
/* TOKEN $AA */
.ascii  "RETUR"
	dc.b  0xce
/* TOKEN $AB */
.ascii "RESTOR"
	dc.b  0xc5
/* TOKEN $AC */
.ascii  "REPOR"
	dc.b  0xd4
/* TOKEN $AD */
.ascii  "RE"
	dc.b  0xcd
/* TOKEN $AE */
.ascii  "REA"
	dc.b  0xc4
/* TOKEN $AF */
.ascii "RU"
	dc.b  0xce
/* TOKEN $B0 */
.ascii  "RENUMBE"
	dc.b  0xd2
/* TOKEN $B1 */
.ascii  "STE"
	dc.b  0xd0
/* TOKEN $B2 */
.ascii  "SAV"
	dc.b  0xc5
/* TOKEN $B3 */
.ascii  "STO"
	dc.b  0xd0
/* TOKEN $B4 */
.ascii  "SOUN"
	dc.b  0xc4
/* TOKEN $B5 */
.ascii "SP"
	dc.b  0xc3
/* TOKEN $B6 */
.ascii  "TRAC"
	dc.b  0xc5
/* TOKEN $B7 */
.ascii  "THE"
	dc.b  0xce
/* TOKEN $B8 */
.ascii  "TAB"
	dc.b  0xa8
/* TOKEN $B9 */
.ascii "UNTI"
	dc.b  0xcc
/* TOKEN $BA */
.ascii  "VD"
	dc.b  0xd5
/* TOKEN $BB */
.ascii  "WIDT"
	dc.b  0xc8
/* TOKEN $BC */
.ascii  "AN"
	dc.b  0xc4
/* TOKEN $BD */
.ascii  "O"
	dc.b  0xd2
/* TOKEN $BE */
.ascii "EO"
	dc.b  0xd2
/* TOKEN $BF */
.ascii  "DI"
	dc.b  0xd6
/* TOKEN $C0 */
.ascii  "MO"
	dc.b  0xc4
/* TOKEN $C1 */
	dc.b  0x3c
	dc.b  0xbd
/* TOKEN $C2 */
	dc.b  0x3c
	dc.b  0xbe
/* TOKEN $C3 */
	dc.b  0x3e
	dc.b  0xbd
/* TOKEN $C4 */
.ascii  "PT"
	dc.b  0xd2
/* TOKEN $C5 */
.ascii "PAG"
	dc.b  0xc5
/* TOKEN $C6 */
.ascii  "TO"
	dc.b  0xd0
/* TOKEN $C7 */
.ascii  "LOME"
	dc.b  0xcd
/* TOKEN $C8 */
.ascii "HIME"
	dc.b  0xcd
/* TOKEN $C9 */
.ascii  "TIM"
	dc.b  0xc5
/* TOKEN $CA */
.ascii  "CHR"
	dc.b  0xa4
/* TOKEN $CB */
.ascii  "GET"
	dc.b  0xa4
/* TOKEN $CC */
.ascii  "INKEY"
	dc.b  0xa4
/* TOKEN $CD */
.ascii  "LEFT$"
	dc.b  0xa8
/* TOKEN $CE */
.ascii  "MID$"
	dc.b  0xa8
/* TOKEN $CF */
.ascii "RIGHT$"
	dc.b  0xa8
/* TOKEN $D0 */
.ascii  "STR"
	dc.b  0xa4
/* TOKEN $D1 */
.ascii  "STRING$"
	dc.b  0xa8
/* TOKEN $D2 */
.ascii  "INSTR"
	dc.b  0xa8
/* TOKEN $D3 */
.ascii  "VA"
	dc.b  0xcc
/* TOKEN $D4 */
.ascii "AS"
	dc.b  0xc3
/* TOKEN $D5 */
.ascii  "LE"
	dc.b  0xce
/* TOKEN $D6 */
.ascii  "GE"
	dc.b  0xd4
/* TOKEN $D7 */
.ascii  "INKE"
	dc.b  0xd9
/* TOKEN $D8 */
.ascii  "ADVA"
	dc.b  0xcc
/* TOKEN $D9 */
.ascii  "PO"
	dc.b  0xd3
/* TOKEN $DA */
.ascii  "VPO"
	dc.b  0xd3
/* TOKEN $DB */
.ascii "COUN"
	dc.b  0xd4
/* TOKEN $DC */
.ascii  "POINT"
	dc.b  0xa8
/* TOKEN $DD */
.ascii  "ER"
	dc.b  0xd2
/* TOKEN $DE */
.ascii "ER"
	dc.b  0xcc
/* TOKEN $DF */
.ascii  "OPENI"
	dc.b  0xce
/* TOKEN $E0 */
.ascii  "OPENOU"
	dc.b  0xd4
/* TOKEN $E1 */
.ascii  "OPENU"
	dc.b  0xd0
/* TOKEN $E2 */
.ascii "EX"
	dc.b  0xd4
/* TOKEN $E3 */
.ascii  "BGET"
	dc.b  0xa3
/* TOKEN $E4 */
.ascii  "EO"
	dc.b  0xc6
/* TOKEN $E5 */
.ascii  "TRU"
	dc.b  0xc5
/* TOKEN $E6 */
.ascii  "FALS"
	dc.b  0xc5
/* TOKEN $E7 */
.ascii "AB"
	dc.b  0xd3
/* TOKEN $E8 */
.ascii  "AC"
	dc.b  0xd3
/* TOKEN $E9 */
.ascii  "AS"
	dc.b  0xce
/* TOKEN $EA */
.ascii  "AT"
	dc.b  0xce
/* TOKEN $EB */
.ascii  "CO"
	dc.b  0xd3
/* TOKEN $EC */
.ascii  "DE"
	dc.b  0xc7
/* TOKEN $ED */
.ascii "EVA"
	dc.b  0xcc
/* TOKEN $EE */
.ascii  "EX"
	dc.b  0xd0
/* TOKEN $EF */
.ascii  "F"
	dc.b  0xce
/* TOKEN $F0 */
.ascii  "IN"
	dc.b  0xd4
/* TOKEN $F1 */
.ascii  "L"
	dc.b  0xce
/* TOKEN $F2 */
.ascii  "LO"
	dc.b  0xc7
/* TOKEN $F3 */
.ascii  "NO"
	dc.b  0xd4
/* TOKEN $F4 */
.ascii "P"
	dc.b  0xc9
/* TOKEN $F5 */
.ascii  "RA"
	dc.b  0xc4
/* TOKEN $F6 */
.ascii  "RN"
	dc.b  0xc4
/* TOKEN $F7 */
.ascii  "SG"
	dc.b  0xce
/* TOKEN $F8 */
.ascii  "SI"
	dc.b  0xce
/* TOKEN $F9 */
.ascii "SQ"
	dc.b  0xd2
/* TOKEN $FA */
.ascii  "TA"
	dc.b  0xce
/* TOKEN $FB */
.ascii  "US"
	dc.b  0xd2
/* TOKEN $FC */
.ascii  "T"
	dc.b  0xcf
	dc.b  0xff

/* TOKENS $FD, $FE UNUSED */
/* TOKEN $FF = LINE NUMBER, or PROC/FN reference, or PROC/FN parameter block

    The LINE NUMBER token is used following GOTO, GOSUB, THEN, ELSE or RESTORE
    tokens. The format is:
        $FF [PP] NNNN AAAAAAAA

    where [PP] is an optional padding byte so that the following fields are at
    even addresses, NNNN is the 16 bit line number, and AAAAAAAA is a 32 bit
    address, initially zero.
    When the line referenced is first required (i.e. the branch is taken or
    the RESTORE statement is executed), it is found by a linear search through
    the program for the line number NNNN. The address of the line is then
    saved in AAAAAAAA for future use.
    If the program is subsequently edited, all $FF tokens have their address
    fields zeroed again to prevent stale addresses causing incorrect operation.

    After any instance of PROC or FN tokens in the program, an FF token is
    inserted, with both NNNN and AAAAAAAA initially zero.
    For an invocation (PROC or FN is not preceded by DEF), the AAAAAAAA field
    is updated to point after the DEF PROC or DEF FN after the first search
    for the PROC or FN by name. The NNNN field remains zero.
    For a definition (PROC or FN is preceded by DEF), the AAAAAAAA field is
    updated on each invocation with the address of a parameter information
    block, as follows:

    Length of name (8 bits)
    Number of parameters (8 bits)
    For each parameter:
        Type of parameter (8 bits - 00=int, 01=FP, FF=string)
        One byte of padding, equal to 0
        Address of parameter (32 bits) - address of actual value for numeric, or of header for string
    Line number of first line of procedure (16 bits)
    Execution address of procedure (after DEF statement and parameter definitions) (32 bits)
 */

/******************************************************************************
 * MAIN ENTRY POINT
 ******************************************************************************/
.align 2
start_basic:
	move.l #0x6000, page            /* Set up PAGE, user stack pointer, HIMEM, format variable */
	lea error-.-2(pc), a0           /* Address to restart at after error */
	moveq #0x13, d0
	trap #gen                       /* Set restart vector in OS */
	lea -512(a7), a0                /* Reserve 512 bytes for supervisor stack */
	move.l a0, user                 /* User stack top */
	lea -4096(a7), a0               /* Reserve 3.5K for user stack */
	move.l a0, himem
	and.w #0xdfff, sr               /* Switch to user mode */
	move.l user, a7                 /* Set user stack pointer */
	clr.b lopt                      /* Default LISTO mode */
	move.l #0x90a, formvar          /* Default value of @% */
new2:
	move.l page, a0
	clr.w (a0)+                     /* Clear program */
	move.l a0, top                  /* Set TOP=LOMEM=PAGE+2 */
	move.l a0, lomem
	clr.b lnflg                     /* No cached line addresses */
	bsr clear                       /* Clear all variable lists */
main:
	move.l user, a7
	move.l himem, a5                /* A5 holds BASIC stack pointer */
	clr.w cline                     /* Current line number = 0 for console command line */
	clr.w (a5)
	moveq #14, d0
	trap #gen                       /* clear escape flag */
	moveq #62, d0
	trap #wrch                      /* Display '>' command prompt */
	lea ibuf, a0
	move.l #0x7e200a, d0
	move.w #255, d1
	trap #gen                       /* Read a line into ibuf */
	bcs escape                      /* Branch if ESCAPE was pressed */
	move.l a0, a6                   /* A6 holds pointer into text being scanned */
	bsr nschar
	bhi.s main                      /* Blank line */
	beq.s notnum                    /* Branch if it doesn't begin with a number */
	bsr cvdb                        /* Convert line number to binary */
	moveq #13, d1
	lea ibuf, a0
rmvlnm:
	move.b (a6)+, (a0)
	cmp.b (a0)+, d1
	bne.s rmvlnm
	lea ibuf, a6
	bsr crunch                      /* Tokenize line */
	bsr edit                        /* Pass to editor for inclusion in stored program */
	bra.s main

/* Line doesn't begin with a number, so it's a command for immediate execution */
notnum:
	lea ibuf, a6
	bsr crunch                      /* Tokenize the line */
	bra l                           /* Jump into the RUN code to execute the line */

/* OS transfers control here when an error occurs */
error:
	and.w #0xdfff, sr               /* Back into user mode */
	tst.w cline
	beq.s error0                    /* skip if current line number = 0 (console command line) */
	trap #msg
.ascii " at line "
	dc.b  0
.align 2
	move.w cline, d0
	move.w d0, erl                  /* save line at which error occurred in ERRLN */
	bsr outlnm                      /* display line number at which error occurred */
error0:
	trap #newl
	bra main
mstk:
	trap #err
	dc.b 4
.ascii  "Mistake"
	dc.b  0
	dc.b  0
.align 2

/* NEW command */
new:
	bsr.s nschar
	bls sy
	bra new2

/* Return the first non-space character from where we are now in D0.B */
nospc:
	cmp.b #32, (a6)+
	beq.s nospc
	move.b -(a6), d0
	rts

/* Return the first non-space character from where we are now in D0.B
 * Also set flags on return depending on type of character
 */
nschar:
	bsr.s nospc

/* Set flags depending on type of character in D0.B
 * NZVC = 0000 for newline (CR)
 * NZVC = 0111 for comma
 * NZVC = 0001 for 0-9
 * NZVC = 0100 for colon
 * NZVC = 1101 for A-Z,a-z
 * NZVC = 0101 for other characters
 *
 * Conditions:
 *  CC  !C              CR or :         (statement terminator)
 *  CS  C               Not CR or :
 *  HI  !C & !Z         CR              (end of line)
 *  LS  C | Z           Not CR
 *  EQ  Z               not digit or CR
 *  NE  !Z              digit or CR
 *  VC  !V              not comma
 *  VS  V               comma
 *  PL  !N              non-alphabetic
 *  MI  N               alphabetic
 *  LE  (N!=V) | Z      not digit or CR
 *  LT  N!=V            alphabetic or comma
 *  GE  N==V            not alphabetic or comma
 *  GT  (N==V) & !Z     digit or CR
 */
char:
	clr -(a7)
	move.l a0, -(a7)
	lea chrtab-.-2(pc), a0
	ext d0
	move.b 0(a0, d0.w), 5(a7)   /* Copy table entry into right place on stack */
	move.l (a7)+, a0
	rtr                         /* Return with CCR set to previously pushed table entry */
chrtab:     /* NZVC */
	dc.b 5      /* 00 */
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b 5
	dc.b  5
	dc.b  0     /* 0D */
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b 5
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b  5     /* 20 */
	dc.b 5
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b  7
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b 1      /* 30 */
	dc.b  1
	dc.b  1
	dc.b  1
	dc.b  1
	dc.b  1
	dc.b  1
	dc.b  1
	dc.b  1
	dc.b  1
	dc.b  4     /* 3A */
	dc.b 5
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b 13     /* 41 */
	dc.b  13
	dc.b  13
	dc.b  13
	dc.b  13
	dc.b  13
	dc.b  13
	dc.b  13
	dc.b  13
	dc.b  13
	dc.b 13
	dc.b  13
	dc.b  13
	dc.b  13
	dc.b  13
	dc.b  13
	dc.b  13
	dc.b  13
	dc.b  13
	dc.b  13
	dc.b 13
	dc.b  13
	dc.b  13
	dc.b  13
	dc.b  13
	dc.b  13    /* 5A */
	dc.b 5
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b  13    /* 61 */
	dc.b  13
	dc.b  13
	dc.b  13
	dc.b  13
	dc.b  13
	dc.b 13
	dc.b  13
	dc.b  13
	dc.b  13
	dc.b  13
	dc.b  13
	dc.b  13
	dc.b  13
	dc.b  13
	dc.b  13
	dc.b 13
	dc.b  13
	dc.b  13
	dc.b 13
	dc.b  13
	dc.b  13
	dc.b  13
	dc.b  13
	dc.b  13
	dc.b  13    /* 7A */
	dc.b 5
	dc.b  5
	dc.b  5
	dc.b  5
	dc.b  5
.align 2

/* Convert ASCII Decimal to 16 bit binary
 * Used for line numbers
 */
cvdb:
	move.l d1, -(a7)
	moveq #0, d1
cvdb1:
	move.b (a6)+, d0
	bsr char
	bhi.s cvdbe
	beq.s cvdbe
	and.w #15, d0
	cmp.w #6553, d1
	bhi il
	mulu #10, d1
	add.w d0, d1
	bcc.s cvdb1
	bra il
cvdbe:
	subq.l #1, a6
	move.l d1, d0
	beq illegal
	move.l (a7)+, d1
	rts
cvbd:
	movem.l d0/d1/a0, -(a7)
	move.l #0x20202020, d1
	move.l d1, (a0)+
	move.b d1, (a0)+
	clr.b (a0)
cvbd1:
	swap d0
	clr.w d0
	swap d0
	divu #10, d0
	swap d0
	add.b #48, d0
	move.b d0, -(a0)
	swap d0
	tst.w d0
	bne.s cvbd1
	movem.l (a7)+, a0/d0/d1
	rts

/* Do a block copy - uses the OS-supplied block copy function
 */
blkmov:
	movem.l d0/d1, -(a7)
	moveq #7, d0
	move.l a2, d1
	sub.l a0, d1
	trap #gen
	movem.l (a7)+, d0/d1
	rts

/* Count the length of a line
 * Take account of any FF tokens
 * An FF token is followed by 6 bytes of reserved space, which must be word-aligned
 */
count2:
	move.l a6, d3
	addq.l #8, d3
	and.w #0xfffe, d3
	move.l d3, a6
	moveq #-1, d3
	bra.s ctlp
count:
	movem.l a6/d3, -(a7)
	moveq #13, d2
	moveq #-1, d3
ctlp:
	cmp.b (a6), d3
	beq.s count2
	cmp.b (a6)+, d2
	bne.s ctlp
	move.l a6, d2
	movem.l (a7)+, a6/d3
	sub.l a6, d2
	rts

/* Find a specific line number in the BASIC program
   Return C=0 if found, C=1 if not
   A0 points to line if found.
 */
findline:
	move.l page, a0
fndlp:
	tst.w (a0)
	beq.s notfd
	cmp.w 2(a0), d0
	beq.s foundline
	bcs.s notfd
	add.w (a0), a0
	bra.s fndlp
notfd:
	move #1, ccr
foundline:
	rts

/* Increment TOP, checking for memory exhaustion
 * If successful, also clear variables and cached addresses for line numbers
 */
inctop:
	move.l a0, -(a7)
	move.l top, a0
	add.w d2, a0
	cmp.l himem, a0
	bcc.s noroom
	move.l a0, top
	move.l a0, lomem
	bsr clear
	bsr clrln
	move.l (a7)+, a0
	rts
noroom:
	trap #err
	dc.b 0
.ascii  "No room"
	dc.b  0
	dc.b  0
.align 2


/* Edit a line of the BASIC program
 */
edit:
	movem.l d0/d1/d2/a0/a1/a2/a3, -(a7)
	bsr findline
	bcc.s exists
	cmp.b #13, (a6)
	beq editend
	bsr count
	move.w d2, -(a7)
	addq.w #1, d2
	and.w #0xfffe, d2
edit1:
	addq.w #4, d2
	move.l top, a2
	bsr inctop
	lea 0(a0, d2.w), a1
	bsr blkmov
	move.w d2, (a0)+
	move.w d0, (a0)+
edit2:
	move.w (a7)+, d2
	subq.w #1, d2
	lsr.w #1, d2
edit2a:
	move.w (a6)+, (a0)+
	dbra d2, edit2a
	bra editend
exists:
	cmp.b #13, (a6)
	bne.s modify
	move.w (a0), d2
	move.l a0, a1
	lea 0(a0, d2.w), a0
	move.l top, a2
	bsr blkmov
	neg.w d2
	bsr inctop
	bra.s editend
modify:
	bsr count
	move.w d2, -(a7)
	addq.w #1, d2
	and.w #0xfffe, d2
	addq.w #4, d2
	move.w (a0), d0
	lea 0(a0, d2.w), a1
	lea 0(a0, d0.w), a0
	move.l top, a2
	sub.w d0, d2
	bsr inctop
	bsr blkmov
	sub.w d0, a0
	add.w d0, d2
	move.w d2, (a0)+
	addq.l #2, a0
	bra edit2
editend:
	movem.l (a7)+, d0/d1/d2/a0/a1/a2/a3
	rts

/* LIST command implementation */
list:
	cmp.b #0x4f, (a6)
	beq listo
	bsr chkprg
	moveq #0, d1
	moveq #-1, d2
	bsr args
	bcc.s list1
	move.w d1, d2
list1:
	move.w d1, d0
	bsr findline
	move.l a0, a1
	moveq #1, d7
	and.b lopt, d7
lstln:
	move.l a1, a2
	move.w (a1)+, d1
	beq.s listend
	moveq #0, d0
	move.w (a1)+, d0
	cmp.w d2, d0
	bhi.s listend
	lea strbf, a0
	bsr cvbd
	moveq #6, d0
	trap #gen
	move.w d7, d6
	bra.s listspc2
listspc:
	moveq #32, d0
	trap #wrch
listspc2:
	dbra d6, listspc
prtln:
	move.b (a1)+, d0
	cmp.b #255, d0
	beq prtlnm
	bsr out
	cmp.b #13, d0
	bne.s prtln
	lea 0(a2, d1.w), a1
	moveq #5, d0
	trap #gen
	bra.s lstln
listend:
	bra l1
listo:
	addq.l #1, a6
	bsr ix
	cmp.l #256, d0
	bcc il
	move.b d0, lopt
	bra l1
prtlnm:
	move.l a1, d0
	addq.l #1, d0
	and.w #0xfffe, d0
	move.l d0, a1
	move.w (a1)+, d0
	beq.s listskip
	bsr outlnm
listskip:
	addq.l #4, a1
	bra prtln

/* Get optional line number arguments for LIST, AUTO, RENUMBER, DELETE commands */
args:
	bsr nschar
	bhi.s argsend
	bne.s args3
	bmi.s sx
	bvc.s sx
	bvs.s args1
args3:
	bsr cvdb
	move.w d0, d1
	bsr nschar
	bhi.s args2
	bne.s sx
	bcc.s sx
	bmi.s sx
	bvc.s sx
args1:
	addq.l #1, a6
	bsr nschar
	bhi.s argsend
	beq.s sx
	bsr cvdb
	move.w d0, d2
	bsr nschar
	bls.s sx
argsend:
	rts
args2:
	move #1, ccr
	rts
sx:
	bra sy


/* OLD command branchout */
oldlnm:
	move.l a0, d3
	addq.l #8, d3
	and.w #0xfffe, d3
	move.l d3, a0
	bra.s old1

/* OLD command */
old:
	bsr nschar
	bls.s sx
	move.l page, a0
	moveq #13, d0
	moveq #-1, d2
	addq.l #4, a0
	move.w #255, d1
old1:
	cmp.b (a0), d2
	beq.s oldlnm
	cmp.b (a0)+, d0
	dbeq d1, old1
	bne badprg
	move.l a0, d0
	sub.l page, d0
	addq.w #1, d0
	bclr #0, d0
	move.l page, a0
	move.w d0, (a0)
	bsr.s chkprg
	move.l top, lomem
	bsr clear
	bsr clrln0
	bra l1

/* Check that the program in memory is consistent, in that there is a proper
 * sequence of lines with apparently correct length fields and a terminator.
 * Update TOP if check successful.
 */
chkprg:
	movem.l a0/d0/d1/d2, -(a7)
	move.l page, a0
	moveq #13, d1
	move.w #260, d2
chkprg2:
	move.w (a0), d0
	beq.s chkprg3
	cmp.w d2, d0
	bcc.s badprg
	add.w d0, a0
	cmp.b -1(a0), d1
	beq.s chkprg2
	cmp.b -2(a0), d1
	beq.s chkprg2
badprg:
	trap #0
	dc.b 0
.ascii  "Bad Program"
	dc.b  0
.align 2
chkprg3:
	addq.l #2, a0
	move.l a0, top
	movem.l (a7)+, a0/d0/d1/d2
	rts

/* AUTO command */
auto:
	moveq #10, d1
	moveq #10, d2
	bsr args
	move.w d1, d3
	move.w d2, d4
auto1:
	moveq #0, d0
	move.w d3, d0
	lea strbf, a0
	bsr cvbd
	moveq #6, d0
	trap #gen
	moveq #32, d0
	trap #wrch
	lea ibuf, a0
	move.w #255, d1
	move.l #0x7e200a, d0
	trap #gen
	bcs escape
	move.w d3, d0
	move.l a0, a6
	bsr crunch
	bsr edit
	add.w d4, d3
	bcs ovfw
	bra auto1

/* RENUMBER command */
renum:
	moveq #10, d1
	moveq #10, d2
	bsr args
	move.l page, a0
	cmp.w #255, d2
	bhi silly
	and.l #0xffff, d1
	and.l #0xffff, d2
	moveq #0, d0
	bra.s renum0a
renum0:
	addq.w #1, d0
	add.w d3, a0
renum0a:
	move.w (a0), d3
	bne.s renum0
	tst.w d0
	beq l1
	subq.w #1, d0
	mulu d2, d0
	add.l d1, d0
	cmp.l #65535, d0
	bhi ovfw
	move.l page, a2
	moveq #13, d3
	moveq #-1, d4
	move.w d1, d7
rnmln:
	move.l a2, a1
	move.w (a1), d0
	beq.s renum1a
	addq.l #4, a1
rnmln1:
	cmp.b (a1), d3
	beq.s rnmln2
	cmp.b (a1)+, d4
	bne.s rnmln1
	move.l a1, d5
	addq.l #1, d5
	and.w #0xfffe, d5
	move.l d5, a1
	move.w (a1), d5
	beq.s rnmskip
	move.l page, a0
	moveq #-1, d6
rnmln4:
	addq.w #1, d6
	cmp.w 2(a0), d5
	beq.s rnmln5
	bcs.s failed
	add.w (a0), a0
	tst.w (a0)
	bne.s rnmln4
failed:
	trap #msg
.ascii "Failed at "
	dc.b  0
	dc.b  0
.align 2
	move.w d0, -(a7)
	move.w d7, d0
	bsr.s outlnm
	trap #newl
	move.w (a7)+, d0
rnmskip:
	addq.l #2, a1
	bra.s rnmln6
rnmln5:
	mulu d2, d6
	add.w d1, d6
	move.w d6, (a1)+
rnmln6:
	addq.l #4, a1
	bra.s rnmln1
rnmln2:
	add.w (a2), a2
	add.w d2, d7
	bra.s rnmln
renum1a:
	move.l page, a0
renum1:
	tst.w (a0)
	beq.s renum2
	move.w d1, 2(a0)
	add.w d2, d1
	add.w (a0), a0
	bra.s renum1
renum2:
	bra l1
outlnm:
	movem.l d1/d2, -(a7)
	and.l #0xffff, d0
	lea strbf, a0
	bsr intasc
	clr.b -(a0)
	lea strbf, a0
	moveq #6, d0
	trap #gen
	movem.l (a7)+, d1/d2
	rts
silly:
	trap #err
	dc.b 0
.ascii  "Silly"
	dc.b  0
	dc.b  0
.align 2

/* DELETE command */
dltcmd:
	moveq #0, d1
	moveq #-1, d2
	bsr args
	bcc.s dltcmd1
	move.w d1, d2
dltcmd1:
	move.w d2, d0
	not.w d0
	or.w d1, d0
	beq sy
	cmp.w d2, d1
	bne.s dltcmd2
	move.w d1, d0
	lea dltcmd3-.-2(pc), a0
	bsr edit
	bra l1
dltcmd2:
	bhi silly
	move.w d1, d0
	bsr findline
	move.l a0, a1
	move.w d2, d0
	bsr findline
	bcs.s dltcmd0
	add.w (a0), a0
dltcmd0:
	move.l top, a2
	bsr blkmov
	sub.l a1, a0
	sub.l a0, a2
	move.l a2, top
	move.l a2, lomem
	bsr clear
	bsr clrln
	bra l1
dltcmd3:
	dc.b 13
	dc.b  0
.align 2

/* SAVE command */
save:
	bsr strexpr
	move.l page, a1
	move.l top, d1
	sub.l a1, d1
	move.l a1, a2
	lea new2-.-2(pc), a3
	moveq #0, d0
	trap #file
	bra l1

/* LOAD command */
load:
	bsr strexpr
	move.l page, a1
	moveq #1, d0
	trap #file
	move.l page, a0
	bsr chkprg
	move.l top, lomem
	bsr.s clear
	bsr clrln0
	bra linend

/* Clear all variables (apart from resident integers) */
clear:
	movem.l a0/d0, -(a7)
	move.l lomem, vartop
	move.w #15, deflen
	lea varca, a0
	moveq #53, d0
clear2:
	clr.l (a0)+
	dbra d0, clear2
	clr.l datptr
	movem.l (a7)+, a0/d0
	rts

/* Clear any cached addresses for line numbers referenced within the program
 * Label 'clrln'
 */
clrln4:
	movem.l (a7)+, a0/a1/d0/d1/d2/d3
	rts
clrln:
	tst.b lnflg
	bne.s clrln0
	rts
clrln0:
	movem.l a0/a1/d0/d1/d2/d3, -(a7)
	clr.b lnflg
	move.l page, a0
clrln1:
	move.l a0, a1
	move.w (a0)+, d0
	beq.s clrln4
	addq.l #2, a0
	moveq #-1, d1
	moveq #13, d2
clrln2:
	cmp.b (a0), d2
	beq.s clrln3
	cmp.b (a0)+, d1
	bne.s clrln2
	move.l a0, d3
	addq.l #3, d3
	and.w #0xfffe, d3
	move.l d3, a0
	clr.l (a0)+
	bra.s clrln2
clrln3:
	lea 0(a1, d0.w), a0
	bra.s clrln1

/* Tokenize a line of BASIC */
crunch:
	movem.l a0/a1/a2/a4/a6/d0/d1/d2, -(a7)
	lea 256(a6), a4
crunch0:
	cmp.b #0x2a, (a6)               /* asterisk? */
	beq.s crunch_end                /* if so, rest of line is OSCLI command, so finish */
crunch2:
	bsr nospc                       /* skip spaces */
	cmp.b #0x41, d0
	bcs.s crunch2a
	cmp.b #0x5a, d0
	bls.s crunch2b
crunch2a:
	cmp.b #0x22, d0
	beq crunch5
	cmp.b #13, d0
	beq.s crunch_end
	cmp.b #0x3c, d0
	bcs.s crunch6
	cmp.b #0x3e, d0
	bhi.s crunch2c
crunch2b:
	lea kwdt-.-2(pc), a0
	move.l a6, a1
	move.l #0x2eff0c, d0
	trap #gen
	bcs.s crunch1
crunch2c:
	move.b (a6)+, d0
	bsr char
	bcc.s crunch4
	bpl.s crunch2
crunch3:
	move.b (a6)+, d0
	bsr char
	bmi.s crunch3
	bcc.s crunch4
	bne.s crunch3
	subq.l #1, a6
	bra.s crunch2
crunch4:
	beq.s crunch0
crunch_end:
	movem.l (a7)+, a0/a1/a2/a4/a6/d0/d1/d2
	rts
crunch6:
	addq.l #1, a6
	bra.s crunch2
crunch1:
	add.b #128, d0
	move.b d0, (a1)+
	move.l a6, a0
	move.l a1, a6
	moveq #13, d1
crunch1a:
	move.b (a0)+, (a1)
	cmp.b (a1)+, d1
	bne.s crunch1a
	cmp.b #0x8b, d0
	beq.s crunch_end
	cmp.b #0x94, d0
	beq.s crunch8
	cmp.b #0x95, d0
	beq.s crunch8
	cmp.b #0xb7, d0
	beq.s crunch8
	cmp.b #0x91, d0
	beq.s crunch8
	cmp.b #0xab, d0
	beq.s crunch8
	cmp.b #0xa7, d0
	beq.s crunch9
	cmp.b #0xef, d0
	beq.s crunch9
	bra crunch2
crunch5:
	addq.l #1, a6
crunch5a:
	move.b (a6)+, d0
	cmp.b #34, d0
	beq.s crunch5b
	cmp.b #13, d0
	bne.s crunch5a
crunch5b:
	bra crunch2
crunch9:
	moveq #0, d0
	move.l a6, a2
	bra.s crunch9a
crunch8:
	move.b (a6)+, d0
	cmp.b #32, d0
	beq.s crunch8
	subq.l #1, a6
	cmp.b #48, d0
	bcs crunch2
	cmp.b #57, d0
	bhi crunch2
	move.l a6, a2
	bsr cvdb
crunch9a:
	move.l a6, a0
	move.l a2, a1
	moveq #13, d1
crunch8a:
	move.b (a0)+, (a1)
	cmp.b (a1)+, d1
	bne.s crunch8a
	moveq #7, d2
	add.l a1, d2
	move.l a2, d1
	btst #0, d1
	bne.s crunch8c
	addq.l #1, d2
crunch8c:
	move.l d2, a0
	cmp.l a4, a0
	bhi lntlng
crunch8b:
	move.b -(a1), -(a0)
	cmp.l a2, a1
	bhi.s crunch8b
	st (a2)+
	move.l a2, d1
	addq.l #1, d1
	and.w #0xfffe, d1
	move.l d1, a2
	move.w d0, (a2)+
	clr.l (a2)+
	move.l a2, a6
crunch8d:
	move.b (a6)+, d0
	cmp.b #32, d0
	beq.s crunch8d
	cmp.b #44, d0
	beq.s crunch8
	subq.l #1, a6
	bra crunch2

/* Output either a character or a token in readable form
 */
out0:
	trap #asci
	rts
out:
	tst.b d0
	bpl.s out0              /* branch out if not token - just print char */
	movem.l a0/d0, -(a7)
	btst #1, lopt
	beq.s out4
	cmp.b #0x93, d0
	bne.s out5
	addq.w #2, d7
	bra.s out4
out5:
	cmp.b #0xa0, d0
	bne.s out4
	cmp.w #2, d7
	bcs.s out4
	subq.w #2, d7
out4:
	btst #2, lopt
	beq.s out6
	cmp.b #0xa9, d0
	bne.s out7
	addq.w #2, d7
	bra.s out6
out7:
	cmp.b #0xb9, d0
	bne.s out6
	cmp.w #2, d7
	bcs.s out6
	subq.w #2, d7
out6:
	lea kwdt-.-2(pc), a0
	and.w #0x7f, d0
	bra.s out1
out2:
	tst.b (a0)+             /* step over a keyword table entry, terminated by char with bit 7 set */
	bpl.s out2
out1:
	dbra d0, out2           /* step past keywords until we get to the one we want */
out3:
	move.b (a0), d0
	and.b #0x7f, d0
	trap #wrch
	tst.b (a0)+
	bpl.s out3
	movem.l (a7)+, a0/d0
	rts

/* CLEAR statement */
clr:
	bsr clear
	bsr clrln0
	bra l1

/* CLS statement */
cls:
	moveq #12, d0
	trap #wrch
	bra l1

/* CLG statement */
clg:
	moveq #16, d0
	trap #wrch
	bra l1

/* STOP statement */
stop:
	trap #err
	dc.b 0
.ascii  "STOP"
	dc.b  0
.align 2

/* BPUT statement */
bput:
	bsr ix
	cmp.b #44, (a6)+
	bne msngcm
	move.b d0, -(a7)
	bsr ix
	swap d0
	move.b (a7)+, d0
	asl.w #8, d0
	move.b #3, d0
	trap #file
	bra l1

/* COLOUR statement */
colour:
	bsr ix
	move.b d0, d1
	moveq #17, d0
	trap #wrch
	move.b d1, d0
	trap #wrch
	bra l1

/* CLOSE statement */
close:
	bsr ix
	asl.w #8, d0
	move.b #4, d0
	trap #file
	bra l1

/* CALL statement */
call:
	bsr ix
	move.l d0, a0
	jsr (a0)
	bra l1

/* CHAIN statement */
chain:
	bsr strexpr
	move.l page, a1
	moveq #1, d0
	trap #file
	move.l page, a0
	bsr chkprg
	bra run

/* Jump table for commands and statements */
.equ	s, stjt
.equ	m, mstk-s
stjt:
    dc.w    sy-s,   sy-s,   sy-s,   sy-s,   sy-s,   sy-s,   sy-s,   sy-s    /* 00-07 */
    dc.w    sy-s,   sy-s,   sy-s,   sy-s,   sy-s,   runln2-s, sy-s, sy-s    /* 08-0F */
    dc.w    sy-s,   sy-s,   sy-s,   sy-s,   sy-s,   sy-s,   sy-s,   sy-s    /* 10-17 */
    dc.w    sy-s,   sy-s,   sy-s,   sy-s,   sy-s,   sy-s,   sy-s,   sy-s    /* 18-1F */
    dc.w    l2-s,   qoke_h-s,   sy-s,   sy-s,   strind_h-s,   sy-s, sy-s,   sy-s    /* 20-27 */
    dc.w    sy-s,   sy-s,   starcmd-s,   sy-s,   sy-s,   sy-s,   sy-s,  sy-s        /* 28-2F */
    dc.w    sy-s,   sy-s,   sy-s,   sy-s,   sy-s,   sy-s,   sy-s,   sy-s            /* 30-37 */
    dc.w    sy-s,   sy-s,   l-s,    sy-s,   sy-s,   fnend-s,   sy-s,    poke_h-s    /* 38-3F */
    dc.w    letfmt_h-s,   letuc-s, letuc-s, letuc-s, letuc-s, letuc-s, letuc-s, letuc-s /* 40-47 */
    dc.w    letuc-s, letuc-s, letuc-s, letuc-s, letuc-s, letuc-s, letuc-s, letuc-s  /* 48-4F */
    dc.w    letuc-s, letuc-s, letuc-s, letuc-s, letuc-s, letuc-s, letuc-s, letuc-s  /* 50-57 */
    dc.w    letuc-s, letuc-s, letuc-s, sy-s,    sy-s,    sy-s,    sy-s,    sy-s     /* 58-5F */
    dc.w    sy-s,    letlc-s, letlc-s, letlc-s, letlc-s, letlc-s, letlc-s, letlc-s  /* 60-67 */
    dc.w    letlc-s, letlc-s, letlc-s, letlc-s, letlc-s, letlc-s, letlc-s, letlc-s  /* 68-6F */
    dc.w    letlc-s, letlc-s, letlc-s, letlc-s, letlc-s, letlc-s, letlc-s, letlc-s  /* 70-77 */
    dc.w    letlc-s, letlc-s, letlc-s, sy-s,    sy-s,    sy-s,    sy-s,    sy-s     /* 78-7F */

	dc.w    auto-s, bput-s, colour-s, clr-s, close-s, cls-s, clg-s, call-s          /* 80-87 */
    dc.w    chain-s, dltcmd-s, draw-s, linend-s, def-s, dim-s, env-s, endproc-s     /* 88-8F */
    dc.w    end-s, linend-s, sy-s, for-s, goto-s, gosub-s, gcol-s, input-s          /* 90-97 */
    dc.w    if-s, list-s, load-s, local-s, let-s, sy-s, mode-s, move-s              /* 98-9F */
    dc.w    next-s, new-s, old-s, on-s, sy-s, oscli1-s, print-s, proc-s             /* A0-A7 */
    dc.w    plot-s, repeat-s, return-s, restore-s, m, linend-s, read-s, run-s       /* A8-AF */
    dc.w    renum-s, sy-s, save-s, stop-s, sound-s, sy-s, m, sy-s                   /* B0-B7 */
    dc.w    sy-s, until-s, vdu-s, m,    sy-s,   sy-s,   sy-s,   sy-s                /* B8-BF */
    dc.w    sy-s,   sy-s,   sy-s,   sy-s,   sy-s,   letpage-s,     sy-s, letlomem-s /* C0-C7 */
    dc.w    lethimem-s, lettime-s,  sy-s,   sy-s,   sy-s,   sy-s,   sy-s,   sy-s    /* C8-CF */
    dc.w    sy-s,   sy-s,   sy-s,   sy-s,   sy-s,   sy-s,   sy-s,   sy-s    /* D0-D7 */
    dc.w    sy-s,   sy-s,   sy-s,   sy-s,   sy-s,   sy-s,   sy-s,   sy-s    /* D8-DF */
    dc.w    sy-s,   sy-s,   sy-s,   sy-s,   sy-s,   sy-s,   sy-s,   sy-s    /* E0-E7 */
    dc.w    sy-s,   sy-s,   sy-s,   sy-s,   sy-s,   sy-s,   sy-s,   sy-s    /* E8-EF */
    dc.w    sy-s,   sy-s,   sy-s,   sy-s,   sy-s,   sy-s,   sy-s,   sy-s    /* F0-F7 */
    dc.w    sy-s,   sy-s,   sy-s,   sy-s,   sy-s,   sy-s,   sy-s,   sy-s    /* F8-FF */

escp:
	bra escape

/* Execute the RUN command */
run:
	move.l user, a7
	move.l himem, a5
	clr.w -(a5)

/* A5 acts as the BASIC Stack Pointer
 *
 * Each frame on the BASIC stack has a 16 bit type field at the lowest address
 * (i.e. at the top of the stack), as follows:
 *      $0095 = GOSUB frame
 *      $00A9 = REPEAT frame
 *      $0093 = FOR frame, integer control variable
 *      $0193 = FOR frame, float control variable
 *      $00A7 = PROC invocation frame
 *      $00EF = FN invocation frame
 *
 * GOSUB frame:
 *      A5 ->   $0095   (2 bytes)
 *              line number of GOSUB statement (2 bytes)
 *              return address (after GOSUB statement) (4 bytes)
 *
 * REPEAT frame:
 *      A5 ->   $00A9   (2 bytes)
 *              line number of REPEAT statement (2 bytes)
 *              return address (after REPEAT statement) (4 bytes)
 *
 * FOR frame (integer control variable)
 *      A5 ->   $0093   (2 bytes)
 *              line number of FOR statement (2 bytes)
 *              return address (after FOR statement) (4 bytes)
 *              step size (4 bytes)
 *              end value (4 bytes)
 *              address of control variable (4 bytes)
 *
 * FOR frame (float control variable)
 *      A5 ->   $0193   (2 bytes)
 *              line number of FOR statement (2 bytes)
 *              return address (after FOR statement) (4 bytes)
 *              step size (6 bytes)
 *              end value (6 bytes)
 *              address of control variable (4 bytes)
 *
 *  PROC/FN invocation frame
 *      A5 ->   $00A7 (PROC) or $00EF (FN)  (2 bytes)
 *              Local variable storage block (previous values of local variables are saved here)
 *              For each local variable or parameter:
 *                  0 (1 byte)
 *                  type 00, 01 or FF (1 byte)
 *                  address of variable (header for strings)
 *                  value (for strings, 2 byte length followed by actual string padded to even length)
 *              $FFFF (2 bytes) terminator
 *              Value of D7 register (4 bytes)
 *              Line number of PROC/FN call  (2 bytes)
 *              Return address (after PROC/FN invocation)   (4 bytes)
 */

/* A6 acts as the BASIC 'Program Counter'
 * i.e. it points to the position in the program text
 * which is next to be interpreted.
 */
	move.l page, a6
	move.l top, lomem
	bsr clear
	bsr clrln
runln:                      /* Execute a line of BASIC */
	move.w (a6)+, d0        /* First word is line length */
	beq.s end               /* If zero, it is the end of the program */
	move.w (a6)+, cline     /* Store current line number */

/* Come here to execute a line directly from the command prompt */
l:
	tst.b esc
	bmi.s escp              /* Break out if ESCAPE pressed */
l2:
    moveq #0, d0
	move.b (a6)+, d0
l3:
    add.w d0, d0
	lea stjt-.-2(pc), a0    /* take jump table entry based on character */
	add.w 0(a0, d0.w), a0
	jmp (a0)

/* Statement begins with * -> pass to OSCLI */
starcmd:
	move.l a6, a0
	moveq #4, d0
	trap #gen

/* Step to the end of the current line, then continue execution at the
 * next line, if there is one.
 */
linend:
	moveq #13, d0
linend2:
	cmp.b (a6)+, d0
	bne.s linend2
runln2:
	move.l a6, d0
	cmp.l page, a6          /* current text ptr < PAGE => console command line, so stop */
	bcs.s end
	addq.l #1, d0
	and.w #0xfffe, d0
	move.l d0, a6           /* round up to even address */
	bra.s runln             /* run next line */
end:
	bra main

/* skip past any spaces at the end of a statement, then carry on with the next statement */
l1:
	move.b (a6)+, d0
	cmp.b #32, d0
	beq.s l1
	cmp.b #58, d0           /* colon? */
	beq.s l                 /* yes - another statement on this line */
	cmp.b #13, d0           /* end of line? */
	beq.s runln2            /* yes - execute next line, if any */
	cmp.b #0x91, d0         /* ELSE token? */
	beq.s linend            /* if yes, we have just executed the THEN part of an IF
                             * so skip to the end of the line before continuing execution
                             */
	bra sy                  /* otherwise, error */
nofn:
	trap #err
	dc.b 7
.ascii  "No FN"
	dc.b  0
	dc.b  0
.align 2
fnend:
	cmp.w #0xef, (a5)+
	bne.s nofn
	bsr expr
	movem.l a0/a1/d0/d1/d6, -(a7)
	bsr pop
	movem.l (a7)+, a0/a1/d0/d1/d6
	rts


/* */
vduw:
	trap #wrch
	ror.w #8, d0
	trap #wrch
	rts

/* MOVE statement */
move:
	move.b #4, -(a7)
	bra.s plot2

/* DRAW statement */
draw:
	move.b #5, -(a7)
	bra.s plot2

/* PLOT statement */
plot:
	bsr ix
	cmp.b #44, (a6)+
	bne msngcm
	move.b d0, -(a7)
plot2:
	bsr ix
	cmp.b #44, (a6)+
	bne msngcm
	move.w d0, -(a7)
	bsr ix
	move.w d0, d1
	move.w (a7)+, d2
	moveq #25, d0
	trap #wrch
	move.b (a7)+, d0
	trap #wrch
	move.w d2, d0
	bsr.s vduw
	move.w d1, d0
	bsr.s vduw
	bra l1

/* GOSUB statement */
gosub:
	subq.l #8, a5
	cmp.l vartop, a5
	bcs stkovfw
	bsr.s getln
	move.l a6, 4(a5)
	move.w cline, 2(a5)
	move.w #0x95, (a5)
	move.l a0, a6
	bra runln
nosuchl:
	trap #err
	dc.b 41
.ascii  "No such line"
	dc.b  0
.align 2

getln:
	move.b (a6)+, d0
	cmp.b #32, d0
	beq.s getln
	addq.b #1, d0
	beq.s getln2
	subq.l #1, a6
	bsr intarg
	cmp.l #65535, d0
	bhi il
	bsr findline
	bcs.s nosuchl
	rts
getln2:
	move.l a6, d0
	addq.l #1, d0
	and.w #0xfffe, d0
	move.l d0, a6
	move.w (a6)+, d0
	move.l (a6), d1
	beq.s getln3
	move.l d1, a0
	addq.l #4, a6
	rts
getln3:
	bsr findline
	bcs.s nosuchl
	move.l a0, (a6)+
	st lnflg
getln4:
	rts

/* GOTO statement */
goto:
	bsr getln
	move.l a0, a6
	bra runln

/* RETURN statement */
return:
	cmp.w #0x95, (a5)+
	bne.s nogsb
	move.w (a5)+, cline
	move.l (a5)+, a6
	bra l
nogsb:
	trap #err
	dc.b 38
.ascii  "No GOSUB"
	dc.b  0
.align 2

/* GCOL statement */
gcol:
	bsr ix
	cmp.b #44, (a6)+
	bne msngcm
	move.b d0, -(a7)
	bsr ix
	move.b d0, d1
	moveq #18, d0
	trap #wrch
	move.b (a7)+, d0
	trap #wrch
	move.b d1, d0
	trap #wrch
	bra l1

/* MODE statement */
mode:
	bsr ix
	cmp.l #7, d0
	bcc il
	move.b d0, d1
	moveq #22, d0
	trap #wrch
	move.b d1, d0
	trap #wrch
	bra l1

oscli1:
	bsr strexpr
	moveq #4, d0
	trap #gen
	bra l1

/* VDU statement */
vdu:
	bsr ix
	cmp.b #0x3b, (a6)
	beq.s vdu2
	trap #wrch
	cmp.b #0x2c, (a6)
	bne l1
	addq.l #1, a6
	bra.s vdu
vdu2:
	bsr vduw
	addq.l #1, a6
vdu3:
	cmp.b #32, (a6)+
	beq.s vdu3
	move.b -(a6), d0
	cmp.b #58, d0
	beq l1
	cmp.b #13, d0
	beq l1
	bra.s vdu
prttab:
	tst.b d7
	bne sy
	bsr intexpr
	cmp.l #256, d0
	bcc il
	move.w #-1, -(a7)
	cmp.b #41, (a6)+
	beq.s prttab1p
	cmp.b #44, -1(a6)
	bne msngbrkt
	move.l d0, -(a7)
	bsr intexpr
	cmp.l #255, d0
	bhi illegal
	move.w d0, 4(a7)
	cmp.b #41, (a6)+
	bne msngbrkt
	move.l (a7)+, d0
prttab1p:
	move.l d0, d1
	move.w #0x8600, d0
	trap #gen
	move.b #31, d0
	trap #wrch
	move.b d1, d0
	trap #wrch
	swap d0
	tst.w (a7)
	bmi.s prttab1
	move.w (a7), d0
prttab1:
	trap #wrch
	addq.l #2, a7
	bra print1
putnwl:
	moveq #10, d0
	bsr.s put
	moveq #13, d0
put:
	cmp.b #13, d0
	bne.s put0a
	clr.w prtct
	bra.s put2
put0a:
	cmp.b #32, d0
	bcs.s put2
	addq.w #1, prtct
put2:
	tst.b d7
	bne.s put1
	trap #wrch
	rts
put1:
	swap d0
	move.b d7, d0
	asl.w #8, d0
	move.b #3, d0
	trap #file
	rts
prttkn:
	cmp.b #0xb8, d0
	beq prttab
	cmp.b #0x91, d0
	beq linend
	cmp.b #0xb5, d0
	bne prtexpr
	bsr intarg
	cmp.l #256, d0
	bcc il
	move.w d0, d1
	bra.s spc2
spc:
	moveq #32, d0
	bsr.s put
spc2:
	dbra d1, spc
	bra.s print1

/* PRINT statement */
print:
	moveq #0, d7
	move.w d7, prtct
	cmp.b #0x23, (a6)
	bne.s print1a
	addq.l #1, a6
	bsr ix
	cmp.b #44, (a6)+
	bne msngcm
	move.b d0, d7
print1:
	bclr #15, d7
print1a:
	move.b (a6)+, d0
	bmi.s prttkn
	cmp.b #32, d0
	beq.s print1a
	cmp.b #58, d0
	beq.s printend
	cmp.b #13, d0
	beq.s printend
	cmp.b #44, d0
	beq.s prtcm
	cmp.b #0x3b, d0
	beq.s prtsmc
	cmp.b #0x27, d0
	beq.s prtnwl
	cmp.b #0x7e, d0
	beq.s prthex
	bne prtexpr
printend:
	subq.l #1, a6
	tst.w d7
	bmi l1
	bsr putnwl
	bra l1
prtnwl:
	bsr putnwl
	bra.s print1
prtsmc:
	bset #15, d7
	bra.s print1a
prtcm:
	moveq #0, d0
	moveq #0, d1
	move.w prtct, d0
	move.b fldsz, d1
	divu d1, d0
	swap d0
	tst.w d0
	beq.s prtcm1
	sub.w d1, d0
	neg.w d0
prtcm1:
	move.w d0, d1
	bra spc2
prthex:
	bsr ix
	lea strbf, a0
	bsr hexasc
	bra numjst
prtexpr:
	subq.l #1, a6
	bsr expr
	tst.b d6
	bpl.s prtnum
	move.l d0, d1
	bra.s prtstr2
prtstr1:
	move.b (a0)+, d0
	bsr put
prtstr2:
	dbra d1, prtstr1
	bra print1
prtnum:
	bne.s prtfp
	bsr intfp
prtfp:
	moveq #0, d6
	lea strbf, a0
	bsr fpasc
	lea strbf+2, a1
	cmp.l a1, a0
	bhi.s prtfp0
	lea strbf, a0
	move.l #0x30303030, d1
	moveq #0, d0
	move.l d1, (a0)+
	move.l d1, (a0)+
	move.w d1, (a0)+
	move.b #13, (a0)+
prtfp0:
	lea strbf, a0
	cmp.b #45, (a0)
	bne.s prtfp1
	addq.l #1, a0
prtfp1:
	moveq #0, d1
	move.b frmtnm, d1
	beq.s prtfp2a
	cmp.b #9, d1
	bls.s prtfp2
prtfp2a:
	moveq #9, d1
prtfp2:
	move.w d1, d2
	moveq #48, d4
	moveq #57, d5
	cmp.b #53, 0(a0, d2.w)
	bcs.s prtfp3
	subq.w #1, d2
prtfp4:
	move.b 0(a0, d2.w), d3
	addq.b #1, d3
	cmp.b d5, d3
	bls.s prtfp5
	move.b d4, 0(a0, d2.w)
	subq.w #1, d2
	bpl.s prtfp4
	move.b #49, (a0)
	addq.b #1, d0
	bra.s prtfp3
prtfp5:
	move.b d3, 0(a0, d2.w)
prtfp3:
	move.b #13, 0(a0, d1.w)
	move.b frmtmd, d6
	beq.s prtfp6
	move.w d1, d2
	subq.w #1, d2
prtfp6a:
	move.b 0(a0, d2.w), 1(a0, d2.w)
	dbra d2, prtfp6a
	move.b #46, 1(a0)
prtfp6b:
	lea 1(a0, d1.w), a0
	move.b #0x45, (a0)+
	ext.w d0
	ext.l d0
	bsr intasc
	bra numjst
prtfp6:
	moveq #1, d3
	cmp.b #-1, d0
	ble.s prtfp6c
	cmp.b d1, d0
	bcc.s prtfp6c
	add.w d0, d3
prtfp6c:
	lea 0(a0, d1.w), a1
	move.w d1, d2
	sub.w d3, d2
	beq.s prtfp6j
	clr.b d4
	bra.s prtfp6e
prtfp6d:
	cmp.b #48, -(a1)
prtfp6e:
	dbne d2, prtfp6d
	beq.s prtfp6n
	addq.l #1, a1
prtfp6n:
	move.b #13, (a1)
prtfp6j:
	cmp.b #-1, d0
	bne.s prtfp6f
	move.w d1, d2
prtfp6i:
	move.b 0(a0, d2.w), 1(a0, d2.w)
	dbra d2, prtfp6i
	move.b #48, (a0)
	move.w d1, d2
	addq.w #1, d2
	bra.s prtfp6h
prtfp6f:
	cmp.b #13, 0(a0, d3.w)
	beq.s prtfp6g
	move.w d1, d2
prtfp6h:
	move.b 0(a0, d2.w), 1(a0, d2.w)
	subq.w #1, d2
	cmp.w d3, d2
	bcc.s prtfp6h
	move.b #46, 0(a0, d3.w)
prtfp6g:
	cmp.b #-1, d0
	blt.s prtfp6k
	beq.s numjst
	cmp.b d1, d0
	bcs.s numjst
prtfp6k:
	moveq #13, d1
	lea strbf, a0
prtfp6m:
	cmp.b (a0)+, d1
	bne.s prtfp6m
	subq.l #1, a0
	move.b #0x45, (a0)+
	ext.w d0
	ext.l d0
	bsr intasc
numjst:
	tst.w d7
	bmi.s numjst2
	moveq #0, d1
	moveq #13, d0
	lea strbf, a0
numjst1:
	addq.w #1, d1
	cmp.b 0(a0, d1.w), d0
	bne.s numjst1
	moveq #0, d0
	move.b fldsz, d0
	cmp.w d0, d1
	bcc.s numjst2
	sub.w d1, d0
	move.w d0, d2
numjst3:
	moveq #32, d0
	bsr put
	subq.w #1, d2
	bne.s numjst3
numjst2:
	lea strbf, a0
numjst2a:
	move.b (a0)+, d0
	cmp.b #13, d0
	beq print1
	bsr put
	bra.s numjst2a

accfmv:
	cmp.b #0x25, (a6)+
	bne sy
	moveq #0, d6
	lea formvar, a0
	rts

/* Access a variable so that it can be written to
 * For non-array variables, if it doesn't exist, create it
 */
access:
	move.b (a6)+, d0
	cmp.b #32, d0
	beq.s access
	cmp.b #64, d0
	bcs sy
access0:
	beq.s accfmv
	sub.b #65, d0
	lea varca, a0
	cmp.b #26, d0
	bcs.s access1
	cmp.b #32, d0
	bcs sy
	lea varsa, a0
	sub.b #32, d0
	cmp.b #25, d0
	bhi sy
	bra.s access2
access1:
	cmp.b #0x25, (a6)
	bne.s access2
	cmp.b #40, 1(a6)
	beq.s access2
	addq.l #1, a6
	ext.w d0
	add.w d0, d0
	add.w d0, d0
	lea resint, a0
	add.w d0, a0
	moveq #0, d6
	rts
access2:
	ext.w d0
	add.w d0, d0
	add.w d0, d0
	add.w d0, a0
	bsr findvar
	bcs.s create
	bvc.s access3
	bsr arrayacc
access3:
	rts

/* Create a new variable */
create:
	bvs nosch2
	tst.b d6
	ble.s create0
	subq.l #1, a1
create0:
	move.l a1, d0
	sub.l a6, d0
	tst.b d6
	bmi.s create1
	bne.s create2
	addq.l #4, d0
	bra.s create3
create2:
	addq.l #6, d0
	bra.s create3
create1:
	add.w deflen, d0
	addq.w #7, d0
create3:
	addq.l #6, d0
	and.w #0xfffe, d0
	add.l vartop, d0
	cmp.l a5, d0
	bhi noroom
	move.l vartop, a2
	move.l d0, vartop
	move.l a2, (a0)
	clr.l (a2)+
	bra.s create4a
create4:
	move.b (a6)+, (a2)+
create4a:
	cmp.l a6, a1
	bne.s create4
	clr.b (a2)+
	move.l a2, d0
	addq.l #1, d0
	and.w #0xfffe, d0
	move.l d0, a2
	tst.b d6
	bmi.s create5
	clr.l (a2)
	move.l a2, a0
	rts
create5:
	lea 6(a2), a3
	move.l a3, (a2)+
	move.b deflen+1, (a2)+
	clr.b (a2)+
	move.b #13, (a2)
	move.l a2, a0
	lea -6(a2), a1
	moveq #0, d0
	rts

/* Assignment to $OPERAND */
strind_h:
strind:
	bsr intarg              /* evaluate integer expression - gives address to write string */
sti2:
	move.b (a6)+, d5
	cmp.b #32, d5           /* skip past spaces */
	beq.s sti2
	cmp.b #61, d5           /* next char must be = */
	bne mstk
	move.l d0, -(a7)        /* save address */
	bsr strexpr             /* get string expression to be written to the location
                               return with D0.W = length, A0 = address
                             */
	move.l (a7)+, a1        /* restore dest addr */
sti3:
	move.b (a0)+, (a1)+     /* copy string + terminator */
	dbra d0, sti3
	bra l1                  /* next statement */

/* Check an operand or expression has numeric type, then convert it to
 * an integer if necessary
 */
intv:
	tst.b d6
	bmi typemis
	bne.s intv1
	move.l (a0), d0
	rts
intv1:
	move.w (a0)+, d1
	move.l (a0), d0
	bra fpint

letind:
	cmp.b #0x24, d0
	beq.s strind
	clr.l -(a7)
	cmp.b #33, d0
	beq.s qoke
	cmp.b #63, d0
	beq.s poke1
	bra sy

/* Assignment to ?OPERAND */
poke_h:
    moveq #0, d0
    bra.s poke2
poke:
	bsr.s intv
poke2:
	move.l d0, -(a7)
poke1:
	bsr intarg
	add.l d0, (a7)
poke0:
	move.b (a6)+, d0
	cmp.b #32, d0
	beq.s poke0
	cmp.b #61, d0
	bne mstk
	bsr ix
	move.l (a7)+, a0
	move.b d0, (a0)
	bra l1

/* Assignment to VAR?OPERAND or VAR!OPERAND */
ltind:
	cmp.b #33, d5       /* check for ! */
	beq.s qoke0         /* yes - do 32 bit indirect assignment */
	cmp.b #63, d5       /* check for ? */
	beq.s poke          /* yes - do 8 bit indirect assignment */
	bra mstk            /* otherwise, error */

/* Assignment to !OPERAND */
qoke_h:
    moveq #0, d0
    bra.s qoke2
qoke0:
	bsr.s intv
qoke2:
	move.l d0, -(a7)
qoke:
	bsr intarg
	add.l d0, (a7)
	btst #0, 3(a7)
	bne aerr
qoke1:
	move.b (a6)+, d0
	cmp.b #32, d0
	beq.s qoke1
	cmp.b #61, d0
	bne mstk
	bsr ix
	move.l (a7)+, a0
	move.l d0, (a0)
	bra l1

/* Statement starts with LET token */
let:
    moveq #0, d0
let1:
    move.b (a6)+, d0
    cmp.b #32, d0                   /* skip spaces */
    beq.s let1
    lea lettab-.-2(pc), a0
    move.w d0, d1
    lsr.w #3, d1
    btst.b d0, 0(a0, d1.w)          /* check for valid token after LET */
    bne l3                          /* if valid, just ignore the LET and proceed */
    bra sy                          /* otherwise, error */
lettab:
    dc.b 0x00, 0x00, 0x00, 0x00     /* characters 00-1F not permitted after LET */
    dc.b 0x13, 0x00, 0x00, 0x80     /* <space>, !, $, ? permitted in range 20-3F */
    dc.b 0xFF, 0xFF, 0xFF, 0x07     /* @, A-Z permitted in range 40-5F */
    dc.b 0xFE, 0xFF, 0xFF, 0x07     /* a-z permitted in range 60-7F */
    dc.b 0x00, 0x00, 0x00, 0x00     /* tokens 80-9F not permitted */
    dc.b 0x00, 0x00, 0x00, 0x00     /* tokens A0-BF not permitted */
    dc.b 0xA0, 0x03, 0x00, 0x00     /* PAGE, LOMEM, HIMEM, TIME permitted in range C0-DF */
    dc.b 0x00, 0x00, 0x00, 0x00     /* tokens E0-FF not permitted */

/* statement starts with @ - must be assignment to format variable
   or indirect assignment with @% as base.
 */
letfmt_h:
    bsr accfmv          /* check for % and get address of @% */
    bra.s let2          /* do the assignment or indirection */

/* statement starts with PAGE - must be assignment to PAGE or
   or indirect assignment with PAGE as base.
 */
letpage:
	lea page, a0
    bra.s letint

/* statement starts with HIMEM - must be assignment to HIMEM or
   or indirect assignment with HIMEM as base.
 */
lethimem:
	lea himem, a0
    bra.s letint

/* statement starts with LOMEM - must be assignment to LOMEM or
   or indirect assignment with LOMEM as base.
 */
letlomem:
	lea lomem, a0

/* Assignment to integer variable pointed to by A0 */
letint:
	moveq #0, d6

/* Assignment to variable pointed to by A0, type in D0.B */
let2:
	move.b (a6)+, d5
	cmp.b #32, d5
	beq.s let2              /* skip spaces */
let3:
	cmp.b #61, d5
	bne ltind               /* if next non-space char is not =, must be indirection ? or ! */
	tst.b d6
	bmi letstr              /* branch if string assignment */
	bne.s letfp             /* branch if float */
	move.l a0, -(a7)        /* save variable address */
	bsr ix                  /* evaluate RHS as integer expression */
	move.l (a7)+, a0        /* restore variable address */

/* Not sure why this is here
 * It disallows writes to addresses below 0x100 unless the type is integer */
 */
	cmp.w #256, a0
	bcc.s letintok
	btst #0, d0
	bne aerr
letintok:
	cmp.w #lomem, a0        /* is assignment to LOMEM? */
    beq.s letlomem2         /* branch out if yes */
	move.l d0, (a0)         /* no, assign the integer */
	bra l1                  /* next statement */
letlomem2:
    cmp.l (a0), d0          /* is LOMEM being modified? */
    beq l1                  /* no - next statement */
    move.l d0, (a0)         /* yes - write new value */
	bsr clear               /* and clear all variables */
	bra l1
letfp:
	move.l a0, -(a7)
	bsr.s fpexpr            /* evaluate RHS as float expression */
	move.l (a7)+, a0
	move.w d1, (a0)+        /* assign float to variable */
	move.l d0, (a0)
	bra l1

/* statement starts with uppercase but not keyword - must be assignment */
letuc:
	cmp.b #0x25, (a6)       /* check if following char is % - if so, may be resident integer */
    bne.s letuc1
	cmp.b #0x28, 1(a6)      /* % found, check if char after % is ( - if so, array, else resident integer */
    bne.s letuc1
    add.w d0, d0            /* d0.w = 4*ASCII value */
    lea resint - 4*65, a0   /* base address of resident integers, offset because d0 = 4*ASCII value */
    add.w d0, a0            /* A0 = address of variable value */
	moveq #0, d6            /* type = integer */

/* variable beginning with uppercase, not resident integer
 * D0.W = 2 * ASCII value
 */
letuc1:
    lsr.w #1, d0
    sub.w #65, d0           /* character value - 'A' */
    lea varca, a0           /* upper case list heads */
    bsr access1             /* find or create variable */
    bra.s let2              /* assign variable */

/* statement starts with lowercase - must be assignment */
letlc:
    lsr.w #1, d0
    sub.w #97, d0           /* character value - 'a' */
    lea varsa, a0           /* lower case list heads */
    bsr access1             /* find or create variable */
    bra let2                /* assign variable */

/* Evaluate an expression and return a floating point result */
fpexpr:
	bsr expr
	tst.b d6
	bmi typemis
	beq intfp
	rts

/* Assign to a string variable */
letstr:
	movem.l a0/a1, -(a7)    /* FIXME: What's in A1? */
	bsr strexpr
	movem.l (a7)+, a2/a3
	bsr.s letstrsub
	bra l1

/* Assign to a string variable
 * String to be assigned has length D0.W, pointer A0
 */
letstrsub:
	cmp.b 4(a3), d0
	bls.s letstr1
	lea 1(a2, d0.w), a1
	cmp.l vartop, a1
	bcs.s letstr3
	move.l a2, vartop
letstr3:
	move.l d0, d1
	addq.l #2, d1
	and.w #0xfffe, d1
	add.l vartop, d1
	cmp.l a5, d1
	bhi noroom
	move.l vartop, a2
	move.l d1, vartop
	move.l a2, (a3)
	move.b d0, 4(a3)
letstr1:
	move.b d0, 5(a3)
	lsr.w #1, d0
letstr2:
	move.w (a0)+, (a2)+
	dbra d0, letstr2
	rts

/* statement starts with TIME - must be assignment to TIME */
lettime:
	move.b (a6)+, d5
	cmp.b #32, d5           /* skip spaces */
	beq.s lettime
	cmp.b #61, d5           /* check for = */
	bne mstk
	bsr ix                  /* evaluate an integer expression */
	rol.w #8, d0            /* D0 = [a3 a2 a0 a1] where a0 = ls byte of arg, a3 = ms byte etc. */
	swap d0                 /* D0 = [a0 a1 a3 a2]
	rol.w #8, d0            /* D0 = [a0 a1 a2 a3] (little endian for 6502) */
	clr.w -(a7)
	move.l d0, -(a7)        /* A7 points to argument (little end), extended with 0000 */
	move.l a7, a1           /* source address for host memory write */
    move.l #(5<<16)|3, d0   /* write 6502 memory, length 5 */
	lea HOST_SIDE_BUF, a0   /* dest addr for host memory write */
	trap #gen               /* write to host memory */
	move.l #(HOST_SIDE_BUF<<16)|0x0201, d0  /* Host OSWORD call 2, argument block at HOST_BUF_PTR */
	trap #gen               /* execute OSWORD call on host */
	addq.l #6, a7           /* pop temporaries off stack */
	bra l1                  /* next statement */

/* REPEAT statement */
repeat:
	moveq #8, d1
	bsr chkstk
	move.l a6, -(a4)
	move.w cline, -(a4)
	move.w #0xa9, -(a4)
	bra l

/* UNTIL statement */
until:
	cmp.w #0xa9, (a5)
	bne.s norpt
	bsr ix
	tst.l d0
	bne.s until0
	move.w 2(a5), cline
	move.l 4(a5), a6
	bra l
until0:
	addq.l #8, a5
	bra l1
norpt:
	trap #err
	dc.b 43
.ascii  "No REPEAT"
	dc.b  0
	dc.b  0
.align 2


noto:
	trap #err
	dc.b 36
.ascii  "No TO"
	dc.b  0
	dc.b  0
.align 2

/* FOR statement */
for:
	bsr access
	moveq #24, d1
	move.b d6, d7
	bmi typemis
	bne.s forfp
	moveq #20, d1
forfp:
	move.b (a6)+, d0
	cmp.b #32, d0
	beq.s forfp
	cmp.b #61, d0
	bne sy
	bsr chkstk
	move.l a0, -(a4)
	tst.b d7
	bne.s forfp1
	bsr ix
	move.l 16(a5), a0
	move.l d0, (a0)
	bra.s for1
forfp1:
	bsr fpx
	move.l 20(a5), a0
	move.w d1, (a0)
	move.l d0, 2(a0)
for1:
	move.b (a6)+, d0
	cmp.b #32, d0
	beq.s for1
	cmp.b #0xfc, d0
	bne.s noto
	tst.b d7
	bne.s forfp2
	bsr ix
	move.l d0, 12(a5)
	bra.s for2
forfp2:
	bsr fpx
	move.l d0, 16(a5)
	move.w d1, 14(a5)
for2:
	move.b (a6)+, d0
	cmp.b #32, d0
	beq.s for2
	cmp.b #0xb1, d0
	beq.s forstep
	subq.l #1, a6
	tst.b d7
	bne.s forfp3
	move.l #1, 8(a5)
	bra.s for3
forfp3:
	move.l #0x80000000, 10(a5)
	move.w #0x81, 8(a5)
	bra.s for3
forstep:
	tst.b d7
	bne.s forfp4
	bsr ix
	move.l d0, 8(a5)
	bra.s for3
forfp4:
	bsr fpx
	move.l d0, 10(a5)
	move.w d1, 8(a5)
for3:
	move.w cline, 2(a5)
	move.l a6, 4(a5)
	move.b d7, (a5)
	move.b #0x93, 1(a5)
	bra l1
nofor:
	trap #err
	dc.b 32
.ascii  "No FOR"
	dc.b  0
.align 2

/* NEXT statement */
next:
	cmp.b #0x93, 1(a5)
	bne.s nofor
	move.b (a5), d7
next1:
	move.b (a6)+, d0
	cmp.b #32, d0
	beq.s next1
	cmp.b #58, d0
	beq.s next2
	cmp.b #13, d0
	beq.s next2
	cmp.b #0x91, d0
	beq.s next2
	subq.l #1, a6
	bsr access
	tst.b d7
	bne.s nextfp
	cmp.l 16(a5), a0
	beq.s next2a
badnxt:
	trap #err
	dc.b 33
.ascii  "Can't match FOR"
	dc.b  0
	dc.b  0
.align 2
nextfp:
	cmp.l 20(a5), a0
	bne.s badnxt
	addq.l #1, a6
next2:
	subq.l #1, a6
next2a:
	tst.b d7
	bne.s nextfp2
	move.l 16(a5), a0
	move.l (a0), d0
	add.l 8(a5), d0
	bvs ovfw
	move.l d0, (a0)
	cmp.l 12(a5), d0
	sgt d0
	slt d2
	moveq #20, d1
	bra.s next3
nextfp2:
	move.l 20(a5), a0
	move.w (a0), d1
	move.l 2(a0), d0
	move.w 8(a5), d3
	move.l 10(a5), d2
	bsr fpadd
	move.l d0, 2(a0)
	move.w d1, (a0)
	move.l 16(a5), d2
	move.w 14(a5), d3
	bsr fpcmp
	tst.b d0
	sgt d0
	slt d2
	moveq #24, d1
next3:
	tst.b 8(a5)
	bpl.s next3a
	move.b d2, d0
next3a:
	tst.b d0
	bmi.s next4
	move.w 2(a5), cline
	move.l 4(a5), a6
	bra l1
next4:
	add.w d1, a5
	bra l1

/* IF statement */
if:
	bsr ix
	tst.l d0
	beq.s if0
	cmp.b #0xb7, (a6)
	bne l
if1:
	addq.l #1, a6
if1a:
	cmp.b #32, (a6)
	beq.s if1
	move.b (a6), d0
	addq.b #1, d0
	bne l
	bra goto
if0:
	moveq #13, d1               /* line terminator */
	moveq #-111, d2             /* ELSE */
	moveq #-104, d3             /* IF */
if2:
	move.b (a6)+, d0            /* get next char */
	cmp.b d1, d0                /* end of line? */
	beq.s if3                   /* yes - finished */
	cmp.b d2, d0                /* ELSE token? */
	beq.s if1a                  /* yes - execute what comes after it */
	cmp.b d3, d0                /* IF token? */
	bne.s if2                   /* if not, look at next char */
	bra linend                  /* else ignore the rest of the line
                                 * since ELSE always binds to the last IF
                                 */
if3:
	subq.l #1, a6
	bra linend
baddim:
	trap #err
	dc.b 10
.ascii  "Bad DIM"
	dc.b  0
	dc.b  0
.align 2

/* DIM statement */
dim:
	move.b (a6)+, d0
	cmp.b #32, d0
	beq.s dim
	sub.b #65, d0
	bcs.s baddim
	lea varca, a0
	cmp.b #25, d0
	bls.s dim1
	sub.b #32, d0
	bcs.s baddim
	cmp.b #25, d0
	bhi.s baddim
	lea varsa, a0
	bra.s dim2
dim1:
	cmp.b #0x25, (a6)
	bne.s dim2
	cmp.b #0x28, 1(a6)
	beq.s dim2
	addq.l #1, a6
	ext.w d0
	asl.w #2, d0
	lea resint, a0
	add.w d0, a0
	bra dimvar3
dim2:
	ext.w d0
	asl.w #2, d0
	add.w d0, a0
	bsr findvar
	bvc dimvar
	bcc baddim
	movem.l a0/a1/a6/d6, -(a7)
	move.l a1, a6
	moveq #1, d7
	moveq #0, d5
dim3:
	move.l d5, -(a7)
	bsr ix
	move.l (a7)+, d5
	tst.l d0
	beq baddim
	cmp.l #65536, d0
	bcc baddim
	mulu d0, d7
	cmp.l #65536, d7
	bcc baddim
	addq.w #1, d5
	move.w d0, -(a7)
	move.b (a6)+, d0
	cmp.b #44, d0
	beq.s dim3
	cmp.b #41, d0
	bne msngbrkt
	add.w d5, d5
	lea 0(a7, d5.w), a4
	movem.l (a4)+, d6/a0/a1/a2
	moveq #4, d4
	tst.b d6
	beq.s dim4
	bpl.s dim5
	move.w deflen, d4
	addq.w #5, d4
dim5:
	addq.w #2, d4
dim4:
	move.l a1, d0
	sub.l a2, d0
	addq.w #8, d0
	add.l d5, d0
	move.w d4, d1
	mulu d7, d1
	add.l d1, d0
	and.w #0xfffe, d0
	move.l vartop, a3
	add.l a3, d0
	cmp.l a5, d0
	bhi noroom
	move.l d0, vartop
	move.l a3, (a0)
	clr.l (a3)+
dim6:
	move.b (a2)+, (a3)+
	cmp.l a1, a2
	bcs.s dim6
	clr.b (a3)+
	move.l a3, d0
	addq.l #1, d0
	and.w #0xfffe, d0
	move.l d0, a3
	addq.w #2, d5
	move.w d5, (a3)+
	subq.w #4, d5
dim7:
	move.w 0(a7, d5.w), (a3)+
	subq.w #2, d5
	bpl.s dim7
	tst.b d6
	bmi.s dimstr
	addq.b #2, d6
	ext.w d6
	mulu d7, d6
	moveq #0, d0
dim8:
	move.w d0, (a3)+
	subq.l #1, d6
	bne.s dim8
	bra.s dimend
dimstr:
	moveq #6, d6
	mulu d7, d6
	lea 0(a3, d6.l), a2
dim9:
	move.l a2, (a3)+
	move.b deflen+1, (a3)+
	clr.b (a3)+
	move.b #13, (a2)
	add.w deflen, a2
	addq.w #1, a2
	subq.w #1, d7
	bne.s dim9
dimend:
	move.l a4, a7
dimnd2:
	move.b (a6)+, d0
	cmp.b #32, d0
	beq.s dimnd2
	cmp.b #44, d0
	beq dim
	subq.l #1, a6
	bra l1
dimvar:
	bcc.s dimvar2
	tst.b d6
	bmi baddim
	bsr create
dimvar2:
	tst.b d6
	bmi baddim
	beq.s dimvar3
	move.l vartop, d0
	bsr intfp
	move.l d0, 2(a0)
	move.w d1, (a0)
	bra.s dimvar4
dimvar3:
	move.l vartop, (a0)
dimvar4:
	bsr ix
	tst.l d0
	bmi baddim
	add.l vartop, d0
	addq.l #1, d0
	and.w #0xfffe, d0
	cmp.l a5, d0
	bhi noroom
	move.l d0, vartop
	bra.s dimnd2



finput:
	addq.l #1, a6
	bsr intarg
	cmp.b #44, (a6)+
	bne msngcm
	cmp.l #255, d0
	bhi il
	move.w #0x200, d7
	move.b d0, d7
	lea strbf, a4
	move.b #13, (a4)
	bra.s input0

/* INPUT statement */
input:
	cmp.b #0x23, (a6)
	beq.s finput
	lea strbf, a4
	move.b #13, (a4)
	moveq #0, d7
input0:
	move.l a4, -(a7)
	bsr nospc
	tst.b d7
	bne.s input5
	bclr #9, d7
	cmp.b #0x9d, d0
	bne.s input1
	bset #9, d7
	addq.l #1, a6
input1:
	bsr nospc
	bset #8, d7
	cmp.b #0x22, d0
	bne.s input2
	bclr #8, d7
	bsr prompt
input2:
	bsr nospc
	cmp.b #0x2c, d0
	beq.s input4
	cmp.b #0x3b, d0
	bne.s input5
input4:
	addq.l #1, a6
	bset #8, d7
input5:
	bsr access
	move.l (a7)+, a4
	bsr.s getdata
	cmp.b #0x2c, (a6)
	bne.s inputend
	addq.l #1, a6
	bra input0
inputend:
	tst.w d7
	bpl l1
	move.l a4, datptr
	bra l1
lntlng:
	trap #err
	dc.b 55
.ascii  "Line too long"
	dc.b  0
	dc.b  0
.align 2

getdata:
	move.l a4, d0
	beq initdat
	cmp.b #13, (a4)
	bne.s getdat1
	tst.w d7
	bmi rddat
	tst.b d7
	bne.s getdat2
	btst #8, d7
	beq.s getdat3
	moveq #63, d0
	trap #wrch
getdat3:
	move.l #0x7e200a, d0
	move.w #240, d1
	move.l a0, -(a7)
	lea strbf, a0
	trap #gen
	move.l (a7)+, a0
	bcs escape
	lea strbf, a4
	bra.s getdat1
getdat2:
	lea strbf, a4
	lea 256(a4), a3
getdat2a:
	move.b d7, d0
	asl.w #8, d0
	move.b #2, d0
	trap #file
	cmp.l a3, a4
	bcc.s lntlng
	move.b d0, (a4)+
	cmp.b #13, d0
	bne.s getdat2a
	lea strbf, a4
getdat1:
	tst.b d6
	bmi.s getstring
	movem.l d6/a0, -(a7)
	move.l a4, a0
nspc:
	cmp.b #32, (a0)+
	beq.s nspc
	subq.l #1, a0
	bsr val2
	move.b d6, d5
	movem.l (a7)+, d6/a0
	tst.b d6
	bne.s getfltpt
	tst.b d5
	beq.s getinteg1
	bsr fpint
getinteg1:
	move.l d0, (a0)
	bra.s advptr
getfltpt:
	tst.b d5
	bne.s getfltpt1
	bsr intfp
getfltpt1:
	move.l d0, 2(a0)
	move.w d1, (a0)
advptr:
	bsr.s advptr0
	bra.s advptr3
getstring:
	move.l a4, a3
	bsr advpts
	move.l a4, d0
	sub.l a3, d0
	cmp.b 4(a1), d0
	bls.s getstring2b
	lea 1(a0, d0.w), a2
	cmp.l vartop, a2
	bcs.s getstring1
	move.l a0, vartop
getstring1:
	move.l vartop, a2
	move.l a2, d1
	add.l d0, d1
	addq.l #2, d1
	and.w #0xfffe, d1
	cmp.l a5, d1
	bhi noroom
	move.l d1, vartop
	move.b d0, 4(a1)
	move.l a2, (a1)
	move.l a2, a0
getstring2b:
	btst #9, d7
	beq getstring3
getstring2:
	move.b d0, 5(a1)
getstring2a:
	move.b (a3)+, (a0)+
	dbra d0, getstring2a
	move.b #13, -(a0)
advptr3:
	cmp.b #44, (a4)
	bne.s advptr4
	addq.l #1, a4
advptr4:
	rts
advptr0:
	moveq #13, d1
	moveq #0x2c, d2
	btst #9, d7
	beq.s advptr1
	move.l d1, d2
advptr1:
	move.b (a4)+, d0
	cmp.b d2, d0
	beq.s advptr2
	cmp.b d1, d0
	bne.s advptr1
advptr2:
	subq.l #1, a4
	rts
getstring3:
	cmp.b #32, (a3)+
	beq.s getstring3
	subq.l #1, a3
	cmp.b #34, (a3)
	bne getstring2
	moveq #0, d0
	addq.l #1, a3
getstring4:
	move.b (a3)+, d1
	cmp.b #13, d1
	beq.s getstring5
	cmp.b #34, d1
	beq.s getstring6
getstring7:
	move.b d1, (a0)+
	addq.w #1, d0
	bra.s getstring4
getstring6:
	cmp.b (a3)+, d1
	beq.s getstring7
	move.b d0, 5(a1)
	move.b #13, (a0)
	lea -1(a3), a4
	bra advptr3
getstring5:
	move.b d0, 5(a1)
	move.b #13, (a0)
	bra msngquot
advpts:
	btst #9, d7
	bne advptr0
advpts1:
	cmp.b #32, (a4)+
	beq.s advpts1
	subq.l #1, a4
	move.l a4, a3
advpts3:
	cmp.b #34, (a4)
	bne advptr0
	addq.l #1, a4
advpts2:
	move.b (a4)+, d0
	cmp.b #13, d0
	beq msngquot
	cmp.b #34, d0
	bne.s advpts2
	bra.s advpts3
prompt:
	addq.l #1, a6
prompt0:
	move.b (a6)+, d0
	cmp.b #13, d0
	beq msngquot
	cmp.b #0x22, d0
	beq.s prompt1
prompt2:
	trap #wrch
	bra.s prompt0
prompt1:
	cmp.b #0x22, (a6)
	beq.s prompt3
	rts
prompt3:
	trap #wrch
	bra.s prompt
outof:
	trap #err
	dc.b 42
.ascii  "Out of DATA"
	dc.b  0
	dc.b  0
.align 2

initdat:
	move.l page, a4
	bsr.s rdnxtl2
	bra getdat1
rdnxtln:
	move.l a4, d0
	addq.l #2, d0
	and.w #0xfffe, d0
	move.l d0, a4
rdnxtl2:
	move.w (a4), d0
	beq.s outof
	cmp.b #0x8b, 4(a4)
	beq.s datfnd
	add.w d0, a4
	bra.s rdnxtl2
datfnd:
	addq.l #5, a4
	rts
rddat:
	bsr.s rdnxtln
	bra getdat1

/* READ statement */
read:
	move.l datptr, a4
	move.w #0x8001, d7
	bra input0

/* RESTORE statement */
restore:
	move.b (a6)+, d0
	cmp.b #32, d0
	beq.s restore
	subq.l #1, a6
	cmp.b #58, d0
	beq.s restore0
	cmp.b #13, d0
	beq.s restore0
	bsr getln
	move.l a0, a4
	bsr.s rdnxtl2
	move.l a4, datptr
	bra l1
restore0:
	clr.l datptr
	bra l1

/* SOUND statement */
sound:
	subq.l #8, a7
	move.l a7, a0
	moveq #3, d7
	bra.s sound1
sound0:
	cmp.b #44, (a6)+
	bne msngcm
sound1:
	move.l a0, -(a7)
	bsr ix
	move.l (a7)+, a0
	rol.w #8, d0
	move.w d0, (a0)+
	dbra d7, sound0
	lea 0x5f0, a0
	move.l a7, a1
	move.l #0x80003, d0
	trap #gen
	move.l #0x5f00701, d0
	trap #gen
	addq.l #8, a7
	bra l1

/* ENVELOPE statement */
env:
	sub.w #14, a7
	move.l a7, a0
	moveq #13, d7
	bra.s env1
env0:
	cmp.b #44, (a6)+
	bne msngcm
env1:
	move.l a0, -(a7)
	bsr ix
	move.l (a7)+, a0
	move.b d0, (a0)+
	dbra d7, env0
	lea 0x5e8, a0
	move.l a7, a1
	move.l #0xe0003, d0
	trap #gen
	move.l #0x5e80801, d0
	trap #gen
	add.w #14, a7
	bra l1

/* ON ... GOTO or ON ... GOSUB statement handling
 */
onsyn:
	trap #err
	dc.b 39
.ascii  "ON syntax"
	dc.b  0
	dc.b  0
.align 2
on8:
	move.l a6, d2
	addq.l #7, d2
	and.w #0xfffe, d2
	move.l d2, a6
	bra.s on4
on7:
	addq.l #2, a7
	bra if1a
on:
	bsr ix
on1:
	move.b (a6)+, d1
	cmp.b #32, d1
	beq.s on1
	move.b d1, -(a7)
	cmp.b #0x94, d1
	beq.s on2
	cmp.b #0x95, d1
	bne.s onsyn
on2:
	subq.l #1, d0
	beq.s on3
on4:
	move.b (a6)+, d1
	cmp.b #255, d1
	beq.s on8
	cmp.b #44, d1
	beq.s on2
	cmp.b #0x91, d1
	beq.s on7
	cmp.b #58, d1
	beq.s onrng
	cmp.b #13, d1
	bne.s on4
onrng:
	trap #err
	dc.b 40
.ascii  "ON range"
	dc.b  0
.align 2
on3:
	bsr getln
	cmp.b #0x94, (a7)+
	beq.s ongoto
	moveq #58, d2
on5:
	move.b (a6)+, d1
	cmp.b #255, d1
	beq.s on9
	cmp.b d2, d1
	beq.s on6
	cmp.b #13, d1
	beq.s on6
	cmp.b #0x91, d1
	bne.s on5
	moveq #13, d2
	bra.s on5
on6:
	subq.l #1, a6
	moveq #8, d1
	bsr chkstk
	move.l a6, -(a4)
	move.w cline, -(a4)
	move.w #0x95, -(a4)
ongoto:
	move.l a0, a6
	bra runln
on9:
	move.l a6, d3
	addq.l #7, d3
	and.w #0xfffe, d3
	move.l d3, a6
	bra.s on5

/* DEF statement */
def:
	move.b (a6)+, d0
	cmp.b #32, d0
	beq.s def
	cmp.b #0xd5, d0
	beq.s stdfln
	cmp.b #0xef, d0
	beq.s nocall
	cmp.b #0xa7, d0
	bne sy
nocall:
	trap #err
	dc.b 56
.ascii  "No call"
	dc.b  0
	dc.b  0
.align 2
stdfln:
	bsr ix
	cmp.l #255, d0
	bhi il
	or.w #1, d0
	move.w d0, deflen
	bra l1

/* User-defined function invocation */
fn:
	move.w #0xef, -(a7)
	bra.s proc2

/* PROC invocation */
proc:
	move.w #0xa7, -(a7)
proc2:
	move.l a6, d0
	addq.l #4, d0
	and.w #0xfffe, d0
	move.l d0, a6
	move.l (a6), d0
	beq findproc
proc3:
	move.l d0, a1
	sub.w #12, a5
	cmp.l vartop, a5
	bcs stkovfw
	move.l d7, 2(a5)
	move.w #-1, (a5)
	move.l (a1), a0
	move.l a5, a4
	moveq #0, d0
	move.b (a0)+, d0
	add.w d0, a6
	addq.l #4, a6
	move.b (a0)+, d0
	bne.s pushparms
	cmp.b #40, (a6)
	bne invoke
badcall:
	trap #err
	dc.b 30
.ascii  "Bad call"
	dc.b  0
.align 2
pushparms:
	move.l a4, -(a7)
	move.w d0, d7
	move.l a0, a2
	move.l a0, a3
pushparm:
	move.b (a2)+, d6
	addq.l #1, a2
	move.l (a2)+, a0
	move.l a0, a1
	bsr localsub
	subq.w #1, d0
	bne.s pushparm
chkparms:
	cmp.b #40, (a6)+
	bne.s badcall
	move.w d7, -(a7)
parm:
	tst.w (a3)+
	bmi.s strparm
	bne.s fpparm
	subq.l #4, a5
	cmp.l vartop, a5
	bcs stkovfw
	move.l a3, -(a7)
	bsr intexpr
	move.l (a7)+, a3
	move.l d0, (a5)
	bra.s nextparm
fpparm:
	subq.l #6, a5
	cmp.l vartop, a5
	bcs stkovfw
	move.l a3, -(a7)
	bsr fpexpr
	move.l (a7)+, a3
	move.w d1, (a5)
	move.l d0, 2(a5)
	bra.s nextparm
strparm:
	move.l a3, -(a7)
	bsr strexpr
	move.l (a7)+, a3
	moveq #3, d1
	add.w d0, d1
	bsr chkstk
	move.l a5, a4
	move.w d0, (a4)+
	lsr.w #1, d0
strparm1:
	move.w (a0)+, (a4)+
	dbra d0, strparm1
nextparm:
	addq.l #4, a3
	subq.w #1, d7
	beq endparms
	cmp.b #44, (a6)+
	beq.s parm
	bra badcall
endparms:
	cmp.b #41, (a6)+
	bne badcall
	move.w (a7)+, d7
	move.l a3, a4
	move.l a4, -(a7)
tfrparm:
	move.l -(a4), a0
	tst.w -(a4)
	bmi.s tfrstrparm
	bne.s tfrfpparm
	move.l (a5)+, (a0)
	bra.s tfrnxtparm
tfrfpparm:
	move.w (a5)+, (a0)+
	move.l (a5)+, (a0)+
	bra.s tfrnxtparm
tfrstrparm:
	move.w (a5)+, d0
	move.l a0, a3
	move.l (a3), a2
	move.l a5, a0
	bsr letstrsub
	move.l a0, a5
tfrnxtparm:
	subq.w #1, d7
	bne.s tfrparm
	move.l (a7)+, a0
	move.l (a7)+, a4
invoke:
	move.w (a7)+, -(a5)
	cmp.l vartop, a5
	bcs stkovfw
	move.w cline, 6(a4)
	move.l a6, 8(a4)
	move.w (a0)+, cline
	move.l (a0)+, a6
	bra l
nosuchproc:
	trap #err
	dc.b 29
.ascii  "No such FN/PROC"
	dc.b  0
	dc.b  0
.align 2
findproc:
	lea 4(a6), a0           /* A6 points to address field of FF token for PROC/FN call site. A0 points to PROC/FN name to be found */
	move.l page, a1         /* A1 points to line being examined */
	move.w #0x8C, d0        /* DEF token */
	bra.s fndprc2
fndprc1a:
	addq.l #4, a7
fndprc1:
	add.w d1, a1
fndprc2:
    move.w (a1), d1         /* D1 = length of current line */
    beq.s nosuchproc        /* if zero, reached end of program */
    lea 4(a1), a2           /* A2 points to first character of line (step over length and line number) */
fndprc2a:
    cmp.b (a2), d0          /* DEF token?*/
    beq.s fndprc2b          /* yes - continue with this line */
    cmp.b #32, (a2)+        /* space? */
    beq.s fndprc2a          /* yes - look at next character */
    bra.s fndprc1           /* no - skip to next line */
fndprc2b:
    addq.l #1, a2           /* skip past DEF token */
fndprc3:
	move.b (a2)+, d2
	cmp.b #32, d2           /* skip spaces between DEF and PROC/FN */
	beq.s fndprc3
	cmp.b 1(a7), d2         /* Check FN or PROC after DEF matches what we are looking for */
	bne.s fndprc1           /* if not, skip to next line */
	move.l a2, d2
	addq.l #4, d2
	and.w #0xfffe, d2       /* D2 = (A2+3) rounded up to even address - points to address field of FF token */
	move.l d2, -(a7)        /* save it */
	addq.l #4, d2           /* step over address field */
	move.l d2, a2           /* A2 now points to PROC/FN name */
	move.l a0, a3           /* A3 points to name being searched for */
	lea proctab-.-2(pc), a4
	moveq #0, d2
	move.b (a3), d2         /* first char of name */
    move.w d2, d3
    lsr.w #3, d3
	btst.b d2, 0(a4, d3.w)  /* use lookup table to check if it a valid character in a PROC/FN name */
	beq badcall             /* if not, error */
fndprc4:
	cmpm.b (a3)+, (a2)+     /* compare against name in line being examined */
	bne.s fndprc1a          /* if not same, skip to next line */
	move.b (a3), d2         /* D2 = character in name being searched for */
    move.w d2, d3
    lsr.w #3, d3
	btst.b d2, 0(a4, d3.w)  /* is it a valid identifier character? */
	bne.s fndprc4           /* if yes, check next character */
	move.b (a2), d3         /* no - get corresponding character in DEF line */
    move.w d3, d2
    lsr.w #3, d2
	btst.b d3, 0(a4, d2.w)  /* valid identifier character? */
    bne.s fndprc1a          /* if yes, names don't match - call name is initial segment of DEF name */
foundproc:
	move.l (a7)+, a4        /* recover pointer to address field in call site FF token */
	move.l a4, (a6)         /* update cached address field at call site */
    st lnflg                /* set flag indicating program addresses have been cached */
	move.l a4, d0
	tst.l (a4)
	bne proc3
	move.l a6, -(a7)
	move.l a3, d0
	sub.l a0, d0
	move.l vartop, (a4)
	move.l vartop, a4
	lea 8(a4), a3
	cmp.l a5, a3
	bhi noroom
	move.l a3, vartop
	move.l a2, a6
	move.b d0, (a4)+
	move.w cline, -(a7)
	move.w 2(a1), cline
	clr.b (a4)+
	moveq #0, d5
	cmp.b #40, (a6)
	bne noparms
	addq.l #1, a6
	move.l a6, -(a7)
ctparms:
	addq.b #1, d5
ctparms1:
	move.b (a6)+, d0
	cmp.b #13, d0
	beq msngbrkt
	cmp.b #41, d0
	beq.s allparms
	cmp.b #40, d0
	beq sy
	cmp.b #44, d0
	bne.s ctparms1
	bra.s ctparms
allparms:
	move.b d5, -1(a4)
	move.l (a7)+, a6
	mulu #6, d5
	add.l vartop, d5
	cmp.l a5, d5
	bhi noroom
	move.l d5, vartop
cvparm:
	move.l a4, -(a7)
	bsr access
	move.l (a7)+, a4
	move.b d6, (a4)+
	bpl.s cvparm1
	move.l a1, a0
cvparm1:
	clr.b (a4)+
	move.l a0, (a4)+
cvparm2:
	move.b (a6)+, d0
	cmp.b #32, d0
	beq.s cvparm2
	cmp.b #44, d0
	beq.s cvparm
	cmp.b #41, d0
	bne msngbrkt
noparms:
	move.w cline, (a4)+
	move.w (a7)+, cline
	move.l a6, (a4)+
	move.l (a7)+, a6
	move.l (a6), d0
	bra proc3
proctab:
/* Table with 1's in bit positions corresponding to characters permitted
 * in PROC/FN names. 0-9, A-Z, a-z, _
 */
    dc.b 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0x03     /* 00 - 3F */
    dc.b 0xFE, 0xFF, 0xFF, 0x87, 0xFE, 0xFF, 0xFF, 0x07     /* 40 - 7F */
    dc.b 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00     /* 80 - BF */
    dc.b 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00     /* C0 - FF */

noproc:
	trap #err
	dc.b 13
.ascii  "No PROC"
	dc.b  0
	dc.b  0
.align 2
endproc:
	cmp.w #0xa7, (a5)+
	bne.s noproc
	bsr.s pop
	bra l1
.equ	pop, .
popvar:
	move.w (a5)+, d0
	bmi endpopvar
	tst.b d0
	bmi.s popstr
	bne.s popfp
	move.l (a5)+, a0
	move.l (a5)+, (a0)
	bra.s popvar
popfp:
	move.l (a5)+, a0
	move.w (a5)+, (a0)+
	move.l (a5)+, (a0)
	bra.s popvar
popstr:
	move.l (a5)+, a0
	move.l (a0), a1
	move.w (a5)+, d0
	move.b d0, 5(a0)
	lsr.w #1, d0
popstr1:
	move.w (a5)+, (a1)+
	dbra d0, popstr1
	bra.s popvar
endpopvar:
	move.l (a5)+, d7
	move.w (a5)+, cline
	move.l (a5)+, a6
	rts


notloc:
	trap #err
	dc.b 12
.ascii  "Not LOCAL"
	dc.b  0
	dc.b  0
.align 2

/* LOCAL statement */
local:
	move.w (a5), d0
	cmp.b #0xa7, d0
	beq.s local1
	cmp.b #0xef, d0
	bne.s notloc
local1:
	bsr access
	move.w (a5)+, -(a7)
	bsr.s localsub
	tst.b d6
	bmi.s local1s
	bne.s local1f
	clr.l (a0)
	bra.s local1e
local1f:
	clr.l (a0)
	clr.w -(a0)
	bra.s local1e
local1s:
	move.l (a1), a0
	clr.b 5(a1)
	move.b #13, (a0)
local1e:
	move.w (a7)+, -(a5)
	cmp.l vartop, a5
	bcs stkovfw
local2:
	move.b (a6)+, d0
	cmp.b #32, d0
	beq.s local2
	cmp.b #44, d0
	beq.s local1
	subq.l #1, a6
	bra l1
localsub:
	tst.b d6
	bmi.s localstr
	bne.s localfp
	sub.w #10, a5
	cmp.l vartop, a5
	bcs stkovfw
	clr.w (a5)
	move.l a0, 2(a5)
	move.l (a0), 6(a5)
	rts
localfp:
	sub.w #12, a5
	cmp.l vartop, a5
	bcs stkovfw
	move.w #1, (a5)
	move.l a0, 2(a5)
	move.w (a0)+, 6(a5)
	move.l (a0), 8(a5)
	rts
localstr:
	moveq #0, d1
	move.b 5(a1), d1
	add.w #9, d1
	bsr chkstk
	move.l a5, a4
	move.w #255, (a4)+
	move.l a1, (a4)+
	move.l (a1), a0
	moveq #0, d1
	move.b 5(a1), d1
	move.w d1, (a4)+
	lsr.w #1, d1
localstr1:
	move.w (a0)+, (a4)+
	dbra d1, localstr1
	rts


/* 68000 Operating System for Electron 2nd processor board
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


/* 6821 PIA register addresses
 *
 * Port A is input from the Electron
 * Port B is output to the Electron
 *
 * Control line CB2 is strobed automatically by the 6821 when the 68000 writes to Port B.
 * Control line CA2 is strobed automatically by the 6821 when the 68000 reads from Port A.
 * Control line CA1 receives a low pulse when the 6502 writes a new byte for the 68000 to read.
 * Control line CB1 receives a low pulse when the 6502 reads the byte previously sent by the 68000.
 */
.equ	in, 0xffff8020
.equ	cin, 0xffff8022
.equ	out, 0xffff8024
.equ	cout, 0xffff8026

/* OS system variables */
.equ	reset, 0x34     /* Reset reason - 0=BREAK, 1=POWER ON RESET, 2=CTRL-BREAK */
.equ	esc, 0x35       /* Flag set when ESCAPE is pressed */
.equ	ldf, 0x36       /* Flag used waiting for LOAD operations to complete */
.equ	nbytes, 0x38    /* Number of bytes */
.equ	piaint, 0x64    /* Interrupt vector used for PIA interrupts (priority 1 autovector) */
.equ	errnum, 0x3e    /* Number of last error */
.equ	rsp, 0x3f       /* Response code we are waiting for */
.equ	restart, 0x40   /* Restart vector - execution resumes from here after an error */
.equ	oshwm, 0x44     /* First free RAM location after OS requirements accounted for */
.equ	rspvec, 0x48    /* Vector called when a response is received */
.equ	endblkv, 0x4c   /* Vector called at the end of a block transfer from 6502 */
.equ	addr, 0x50      /* Address where next byte from 6502 will be stored */
.equ	xaddr, 0x54     /* Address used by 6502 commands */
.equ	len, 0x58       /* Number of bytes remaining to receive from 6502 before end of block */
.equ	p, 0x5c         /* Used to receive 6502 registers following OS calls executed on 6502 */
.equ	y, 0x5d
.equ	x, 0x5e
.equ	a, 0x5f
.equ	errvec, 0x80    /* TRAP#0 vector address - error handler */
.equ	wrcvec, 0x84    /* TRAP#1 vector address - OSWRCH handler */
.equ	rdcvec, 0x88    /* TRAP#2 vector address - OSRDCH handler */
.equ	genvec, 0x8c    /* TRAP#3 vector address - OSGEN handler */
.equ	filevec, 0x90   /* TRAP#4 vector address - OSFILE handler */

/* TRAP numbers */
.equ	err, 0
.equ	wrch, 1
.equ	rdch, 2
.equ	gen, 3
.equ	file, 4
.equ	hex, 5
.equ	asci, 6
.equ	newl, 7
.equ	msg, 8

    .section .text
    .global START

/* Boot ROM jumps here after either warm reset or downloading the OS
 * D7 contains the reset reason passed from the Electron
 * 
 * PIA DDRs and control registers have already been initialized by
 * the boot ROM.
 */
START:
	move.b d7, reset            /* save reset reason */
	clr.b errnum
	moveq #9, d0
	lea exctab1-.-2(pc), a0
	lea 8, a1
	move.l a0, a2
init1:
	move.w (a2)+, d1
	lea 0(a0, d1.w), a3
	move.l a3, (a1)+            /* initialize exception vector table (vectors 2-9) */
	dbra d0, init1
	moveq #23, d0
	lea exctab2-.-2(pc), a0
	lea 0x60, a1
	move.l a0, a2
init2:
	move.w (a2)+, d1
	lea 0(a0, d1.w), a3
	move.l a3, (a1)+            /* initialize exception vector table (vectors 24-47) */
	dbra d0, init2
	lea reenter0-.-2(pc), a0
	move.l a0, restart          /* point restart vector to reenter0 */
	lea endprg-.-2+255(pc), a0
	move.l a0, d0
	clr.b d0
	move.l d0, oshwm            /* set OSHWM to next page boundary after OS code */
reenter:
	clr.b esc
	clr.l nbytes
	st rsp
	move.l 0, a7                /* reset stack pointer to initial value */
	move.b #0x2d, cin           /* enable PIA CA1 interrupts (when 6502 sends data to us) */
	move.w #0x2000, sr          /* enable interrupts in the processor */
	bra.s .                     /* wait for an interrupt */
exctab1:
	dc.w berr-exctab1, aerr-exctab1, illegal-exctab1
	dc.w divby0-exctab1, chkerr-exctab1, overflow-exctab1
	dc.w priv-exctab1, trace-exctab1, aopc-exctab1, fopc-exctab1
.equ	dof, int3-exctab2
exctab2:
	dc.w dof, int-exctab2, dof, dof, dof, dof, dof, dof     /* IRQ autovectors */
	dc.w error-exctab2, oswrch-exctab2, osrdch-exctab2      /* TRAP vectors 0, 1, 2 */
	dc.w osgen-exctab2, osfile-exctab2, prthex-exctab2      /* TRAP vectors 3, 4, 5 */
	dc.w osasci-exctab2, osnewl-exctab2, msg1-exctab2       /* TRAP vectors 6, 7, 8 */
	dc.w dof, dof, dof, dof, dof, dof, dof                  /* TRAP vectors 9-15 */

/* PIA interrupt service routine */
int:
	tst.l nbytes
	beq.s int2                  /* branch out if block receive not active */
	move.l a6, -(a7)
	move.l addr, a6
	move.b in, (a6)+            /* block transfer in progress, store byte at next address */
	move.l a6, addr             /* update address */
	move.l (a7)+, a6
	subq.l #1, nbytes           /* decrement byte count */
	bne.s int3
	move.l endblkv, -(a7)       /* if reached end of block, call end of block vector */
	beq.s int0
	rts
int0:
	addq.l #4, a7
int3:
	rte
int2:
	move.l d0, -(a7)
	move.b in, d0               /* get byte from 6502 */
	bmi.s int4                  /* branch if command */
	cmp.b rsp, d0               /* check if expected response code */
	bne.s int5
	st rsp                      /* if yes, set response code to 0xFF and call response received vector */
	move.l rspvec, -(a7)
	beq.s int5a
	rts
int5a:
	addq.l #4, a7
int5:
	move.l (a7)+, d0
	rte
int4:
	and.w #127, d0
	cmp.b #maxcmd, d0
	bhi.s int5                  /* if command unrecognised, ignore it */
	asl.w #2, d0
	jmp cmdt-.-2(pc, d0.w)      /* jump to command handler */
cmdt:
	bra inkey
	bra esckey
	bra errhnd
	bra int5
	bra sta
	bra rda
	bra ina
	bra dea
	bra rdm
	bra wrm
	bra rdb
	bra wrb
	bra exe
	bra tct
.equ	maxcmd, 13

inkey:
	move.l (a7)+, d0
	rte

/* ESCAPE pressed notification - set escape flag */
esckey:
	st esc
	move.l (a7)+, d0
	rte

/* Wait for a byte from the 6502 and read it */
inch:
	tst.b cin
	bpl.s inch
	move.b in, d0
	rts

/* An error has occurred on the 6502 */
errhnd:
	bsr.s inch
	move.b d0, errnum
	bra recover

/* Set address command */
sta:
	clr.l endblkv
	move.l #4, nbytes
	move.l #xaddr, addr
	move.l (a7)+, d0
	rte

/* Read address command */
rda:
	moveq #-123, d0
	bsr.s outch
	move.b xaddr, d0
	bsr.s outch
	move.b xaddr+1, d0
	bsr.s outch
	move.b xaddr+2, d0
	bsr.s outch
	move.b xaddr+3, d0
	bsr.s outch
	move.l (a7)+, d0
	rte

/* Write a byte to the 6502, waiting for previous byte to be read */
outch:
	tst.b out
	move.b d0, out
outch2:
	tst.b cout
	bpl.s outch2
	rts

/* Increment address command */
ina:
	addq.l #1, xaddr
	move.l (a7)+, d0
	rte

/* Decrement address command */
dea:
	subq.l #1, xaddr
	move.l (a7)+, d0
	rte

/* Read memory command */
rdm:
	moveq #-120, d0
	bsr.s outch
	move.l a0, -(a7)
	move.l xaddr, a0
	move.b (a0), d0
	move.l (a7)+, a0
	bsr.s outch
	move.l (a7)+, d0
	rte

/* Write memory command */
wrm:
	clr.l endblkv
	move.l #1, nbytes
	move.l xaddr, addr
	move.l (a7)+, d0
	rte

/* Read memory block command */
rdb:
	move.l a0, -(a7)
	lea rdb2-.-2(pc), a0
	move.l a0, endblkv
	move.l (a7)+, a0
	move.l #4, nbytes
	move.l #len, addr
	move.l (a7)+, d0
	rte
rdb2:
	movem.l a0/d0, -(a7)
	move.l xaddr, a0
rdb3:
	move.b (a0)+, d0
	bsr outch
	subq.l #1, len
	bne.s rdb3
	movem.l (a7)+, a0/d0
	rte

/* Write memory block command */
wrb:
	move.l a0, -(a7)
	lea wrb2-.-2(pc), a0
	move.l a0, endblkv
	move.l (a7)+, a0
	move.l #4, nbytes
	move.l #len, addr
	move.l (a7)+, d0
	rte
wrb2:
	clr.l endblkv
	move.l xaddr, addr
	move.l len, nbytes
	rte

/* Execute subroutine command
 */
exe:
	move.l a0, -(a7)
	move.l xaddr, a0
	jsr (a0)
	move.l (a7)+, a0
	moveq #-116, d0
	bsr outch
	move.l (a7)+, d0
	rte

/* Take control command
 */
tct:
	move.l 0, a7
	move.w #0x2000, sr
	move.l xaddr, a0
	jmp (a0)


/* TRAP#0 handler - ERROR - error occurred (similar to BBC BRK)
 */
error:
	trap #newl
	move.l 2(a7), a0
	move.b (a0)+, errnum
	bsr msg2
recover:
	move.l 0, a7
	clr.l nbytes
	move.w #0x2000, sr
	move.l restart, a0
	clr.b esc
	st rsp
	jmp (a0)
reenter0:
	trap #newl
	bra reenter

/* TRAP#6 handler - OSASCI - Output character in D0.B, preceding CR with LF
 */
osasci:
	cmp.b #13, d0
	bne.s oswrch

/* TRAP#7 handler - OSNEWL - Output a newline (LF followed by CR)
 */
osnewl:
	move.b #10, d0
	trap #wrch
	move.b #13, d0

/* TRAP#0 handler - OSWRCH - Output a character in D0.B
 */
oswrch:
	move.b d0, -(a7)
	clr.b d0
	bsr outch
	move.b (a7)+, d0
	bsr outch
	rte

/* TRAP#1 handler - OSRDCH - Input a character into D0.B
 */
osrdch:
	move.w #0x2000, sr
	move.l d0, -(a7)
osrdch1:
	tst.b esc
	bmi.s osrdche
	move.l #0x8100, d0
	trap #gen
	swap d0
	tst.b d0
	bne.s osrdch1
	rol.l #8, d0
	move.b d0, 3(a7)
	move.l (a7)+, d0
	clr.b 1(a7)
	rte
osrdche:
	move.l (a7)+, d0
	move.b #27, d0
	st 1(a7)
endexc:
	rte

/* TRAP#3 handler - OSGEN - General purpose functions
    Similar to combination of OSBYTE+OSWORD+OSCLI on BBC
 */
osgen:
	cmp.b #maxgen, d0
	bhi.s endexc
	move.l a6, -(a7)
	move.l d0, -(a7)
	and.w #255, d0
	add.w d0, d0
	lea gentab-.-2(pc), a6
	add.w 0(a6, d0.w), a6
	move.l (a7)+, d0
	jsr (a6)
	move.l (a7)+, a6
	rte

/* OSGEN call table */
gentab:
	dc.w osbyte-gentab
	dc.w osword-gentab
	dc.w readm-gentab
	dc.w wrtm-gentab
	dc.w oscli-gentab
	dc.w testesc-gentab
	dc.w msg2-gentab
	dc.w blkmov-gentab
	dc.w prthex4-gentab
	dc.w prthex8-gentab
	dc.w line-gentab
	dc.w sline-gentab
	dc.w match-gentab
	dc.w readesc-gentab
	dc.w clresc-gentab
	dc.w rdreset-gentab
	dc.w rderrnm-gentab
	dc.w rdoshwm-gentab
	dc.w rdrstrt-gentab
	dc.w strstrt-gentab
	dc.w inhex8-gentab
	dc.w inhex16-gentab
	dc.w inhex32-gentab
	dc.w flvdu-gentab
.equ	maxgen, 23

/* Execute OSWORD call on 6502 */
osword:
	move.b #4, d0
	bra.s osbyte0

/* Execute OSBYTE call on 6502 */
osbyte:
	move.b #3, d0
osbyte0:
	move.b d0, rsp
	bsr outch
	ror.l #8, d0
	bsr outch
	ror.l #8, d0
	bsr outch
	ror.l #8, d0
	bsr outch
	lea osbyte2-.-2(pc), a6
	move.l a6, rspvec
	bsr.s waitrsp
	move.l p, d0
	rts

/* Wait for the 6502 to respond to a previously-sent command */
waitrsp:
	move.w #0x2000, sr
waitrsp1:
	tst.b rsp
	bpl.s waitrsp1
waitrsp2:
	tst.l nbytes
	bne.s waitrsp2
	rts
osbyte2:
	clr.l endblkv
	move.l #4, nbytes
	move.l #p, addr
	move.l (a7)+, d0
	rte

/* Set the 6502 address pointer */
setaddr:
	move.b #0x10, d0
	bsr outch
	move.w a0, d0
	ror.w #8, d0
	bsr outch
	ror.w #8, d0
	bra outch

/* Read 6502 memory */
readm:
	bsr.s setaddr
	move.b #0x16, d0
	move.b d0, rsp
	bsr outch
	rol.l #8, d0
	bsr outch
	rol.l #8, d0
	bsr outch
	move.w d0, p
	lea readm2-.-2(pc), a6
	move.l a6, rspvec
	bsr.s waitrsp
	rts

readm2:
	move.l a1, addr
	clr.w nbytes
	move.w p, nbytes+2
	clr.l endblkv
	move.l (a7)+, d0
	rte

/* Write 6502 memory */
wrtm:
	bsr setaddr
	move.b #0x17, d0
	bsr outch
	rol.l #8, d0
	bsr outch
	rol.l #8, d0
	bsr outch
	movem.l d1/a1, -(a7)
	move.w d0, d1
	beq.s wrtm0
	subq.w #1, d1
wrtm1:
	move.b (a1)+, d0
	bsr outch
	dbra d1, wrtm1
wrtm0:
	movem.l (a7)+, a1/d1
	rts

/* Execute an OSCLI command, either locally or on the 6502 */
oscli:
	move.l a0, -(a7)
	move.l a0, a6
	bsr nospc
	cmp.b #46, d0
	beq.s oscli6
	lea clitab-.-2(pc), a0
	move.l #0x2edf0c, d0
	trap #gen
	bcc.s oscli6
	add.w d0, d0
	lea clijt-.-2(pc), a0
	add.w 0(a0, d0.w), a0
	jsr (a0)
	move.l (a7)+, a0
	rts
oscli6:
	move.b #5, d0
	bsr outch
	move.b d0, rsp
	clr.l rspvec
	move.l a6, a0
oscli1:
	move.b (a0)+, d0
	bsr outch
	cmp.b #13, d0
	bne.s oscli1
	bsr waitrsp
	move.l (a7)+, a0
	rts

/* TRAP#4 handler - OSFILE - File System Operations
 */
osfile:
	cmp.b #maxfile, d0
	bhi.s osfile0
	move.l a6, -(a7)
	move.l d0, -(a7)
	and.w #255, d0
	add.w d0, d0
	lea filetab-.-2(pc), a6
	add.w 0(a6, d0.w), a6
	move.l (a7)+, d0
	jsr (a6)
	move.l (a7)+, a6
osfile0:
	rte
filetab:
	dc.w save-filetab
	dc.w load-filetab
	dc.w bget-filetab
	dc.w bput-filetab
	dc.w close-filetab
	dc.w openin-filetab
	dc.w openout-filetab
	dc.w openup-filetab
	dc.w eof-filetab
.equ	maxfile, 8

/* Send a filename to the 6502 */
outname:
	movem.l a0/d0, -(a7)
outnm1:
	move.b (a0)+, d0
	cmp.b #32, d0
	bne.s outnm2
	moveq #13, d0
outnm2:
	bsr outch
	cmp.b #13, d0
	bne.s outnm1
	movem.l (a7)+, a0/d0
	rts

/* Send a 4 byte value to the 6502 */
out4:
	rol.l #8, d0
	bsr outch
	rol.l #8, d0
	bsr outch
	rol.l #8, d0
	bsr outch
	rol.l #8, d0
	bra outch

/* Save operation handler */
save:
	move.b #6, d0
	move.b d0, rsp
	clr.l rspvec
	bsr outch
	bsr.s outname
	move.l d1, d0
	bsr.s out4
	move.l a2, d0
	bsr.s out4
	move.l a3, d0
	bsr.s out4
	bsr waitrsp
	movem.l a1/d1, -(a7)
save1:
	move.b (a1)+, d0
	bsr outch
	tst.b esc
	bmi escape
	subq.l #1, d1
	bne.s save1
	movem.l (a7)+, a1/d1
	rts

/* Load operation handler */
load:
	move.b #7, d0
	move.b d0, rsp
	bsr outch
	bsr outname
	lea load2-.-2(pc), a6
	move.l a6, rspvec
	clr.b ldf
	move.w #0x2000, sr
loadwt:
	tst.b ldf
	beq.s loadwt
	rts
load2:
	move.l #len, addr
	move.l #8, nbytes
	lea load3-.-2(pc), a6
	move.l a6, endblkv
	move.l (a7)+, d0
	rte
load3:
	move.l len, a2
	move.l len+4, a3
	move.l a1, d0
	bne.s load3a
	move.l a2, a1
load3a:
	lea load4-.-2(pc), a6
	move.l a6, endblkv
	move.l #len+2, addr
	move.l #2, nbytes
	rte
load4:
	move.l a1, addr
	move.w len+2, nbytes+2
	beq.s loadend
	clr.w nbytes
	tst.b len+2
	bmi.s ldabort
	lea load5-.-2(pc), a6
	move.l a6, endblkv
	rte
load5:
	move.l addr, a1
	tst.b len+2
	beq.s loadend
	move.l #len+2, addr
	move.l #2, nbytes
	lea load4-.-2(pc), a6
	move.l a6, endblkv
	rte
loadend:
	st ldf
	clr.l nbytes
	rte
ldabort:
	move.b len+2, d0
	clr.l nbytes
	cmp.b #0x81, d0
	beq escape
	move.b len+3, errnum
	bra recover

/* BGET handler */
bget:
	move.b #2, d0
	move.b d0, rsp
	lea bget2-.-2(pc), a6
	move.l a6, rspvec
	bsr outch
	ror.w #8, d0
	bsr outch
	bsr waitrsp
	move.b p, d0
	rts
bget2:
	move.l #1, nbytes
	move.l #p, addr
	clr.l endblkv
	move.l (a7)+, d0
	rte

/* BPUT handler */
bput:
	move.b #1, d0
	bsr outch
	ror.l #8, d0
	bsr outch
	ror.l #8, d0
	bsr outch
	rts

/* File close handler */
close:
	move.b #0x0b, d0
	move.b d0, rsp
	clr.l rspvec
	bsr outch
	ror.w #8, d0
	bsr outch
	bra waitrsp

/* File open handler */
.equ	openin, .
.equ	openout, .
openup:
	addq.b #3, d0
	move.b d0, rsp
	lea openrsp-.-2(pc), a6
	move.l a6, rspvec
	bsr outch
	bsr outname
	bsr waitrsp
	move.b p, d0
	rts
openrsp:
	move.l #1, nbytes
	move.l #p, addr
	clr.l endblkv
	move.l (a7)+, d0
	rte

/* End of file query handler */
eof:
	asl.l #8, d0
	move.w #0x7f00, d0
	trap #gen
	lsr.w #8, d0
	tst.b d0
	sne 9(a7)
	rts

/* Handle an escape by throwing an error */
escape:
	trap #0
	dc.b 17
.ascii  "Escape"
	dc.b  0
.align 2
testesc:
	tst.b esc
	bmi.s escape
	rts

/* TRAP#8 - OSMSG - Display a message inlined in the code after the call
 */
msg1:
	move.l a0, -(a7)
	move.l 6(a7), a0
	bsr.s msg2
	move.l a0, 6(a7)
	addq.l #1, 6(a7)
	and.w #0xfffe, 8(a7)
	move.l (a7)+, a0
	rte
msg2:
	move.w d0, -(a7)
	clr.w d0
	move.w d1, -(a7)
	move.l a1, -(a7)
	clr.b d1
	lea vdutab-.-2(pc), a1
msg3:
	move.b (a0)+, d0
	tst.b d1
	bne.s msg4
	tst.b d0
	beq.s msgend
	cmp.b #32, d0
	bcc.s msg5
	move.b 0(a1, d0.w), d1
msg4:
	subq.b #1, d1
msg5:
	trap #wrch
	bra.s msg3
msgend:
	move.l (a7)+, a1
	move.w (a7)+, d1
	move.w (a7)+, d0
	rts
vdutab:
	dc.b 1
	dc.b  2
	dc.b  1
	dc.b  1
	dc.b  1
	dc.b  1
	dc.b  1
	dc.b  1
	dc.b  1
	dc.b  1
	dc.b 1
	dc.b  1
	dc.b  1
	dc.b  1
	dc.b  1
	dc.b  1
	dc.b  1
	dc.b  2
	dc.b  3
	dc.b  6
	dc.b  1
	dc.b  1
	dc.b  2
	dc.b 10
	dc.b  9
	dc.b  6
	dc.b  1
	dc.b  1
	dc.b  5
	dc.b  5
	dc.b  1
	dc.b  3
.align 2

/* TRAP#5 handler - Print a value in hex
 */
prthex:
	move.b d0, -(a7)
	lsr.b #4, d0
	bsr.s prthex1
	move.b (a7), d0
	and.b #15, d0
	bsr.s prthex1
	move.b (a7)+, d0
	rte
prthex1:
	cmp.b #10, d0
	bcs.s prthex2
	addq.b #7, d0
prthex2:
	add.b #48, d0
	trap #wrch
	rts
prthex8:
	swap d1
	bsr.s prthex4
	swap d1
prthex4:
	move.w d1, d0
	rol.w #8, d0
	trap #hex
	move.w d1, d0
	trap #hex
dummy:
	rts

/* Bus error exception handler
 */
berr:
	trap #newl
	trap #msg
.ascii "Bus Error"
	dc.b  0
.align 2
	bra.s aberr

/* Address error exception handler
 */
aerr:
	trap #newl
	trap #msg
.ascii "Address Error"
	dc.b  0
.align 2
aberr:
	trap #newl
	trap #msg
.ascii "Access type "
	dc.b  0
.align 2
	move.b 1(a7), d0
	trap #hex
	trap #newl
	trap #msg
.ascii "Cycle address "
	dc.b  0
.align 2
	move.l 2(a7), d1
	bsr prthex8
	trap #newl
	trap #msg
.ascii "Instruction opcode "
	dc.b  0
.align 2
	move.w 6(a7), d1
	bsr prthex4
	trap #newl
	trap #msg
.ascii "Status register "
	dc.b  0
.align 2
	move.w 8(a7), d1
	bsr prthex4
	trap #newl
	trap #msg
.ascii "Program Counter "
	dc.b  0
.align 2
	move.l 10(a7), d1
	bsr prthex8
	bra recover

/* Illegal instruction exception handler
 */
illegal:
	trap #newl
	trap #msg
.ascii "Illegal instruction"
	dc.b  0
.align 2
	bra intexc

/* Division by zero exception handler
 */
divby0:
	trap #newl
	trap #msg
.ascii "Division by zero"
	dc.b  0
	dc.b  0
.align 2
	bra intexc

/* CHK instruction exception handler
 */
chkerr:
	trap #newl
	trap #msg
.ascii "CHK out of range"
	dc.b  0
	dc.b  0
.align 2
	bra intexc

/* Overflow exception handler
 */
overflow:
	trap #newl
	trap #msg
.ascii "Overflow"
	dc.b  0
	dc.b  0
.align 2
	bra intexc

/* Privilege violation exception handler
 */
priv:
	trap #newl
	trap #msg
.ascii "Privilege violation"
	dc.b  0
.align 2
	bra intexc

/* Trace exception handler
 */
trace:
	trap #newl
	trap #msg
.ascii "Trace mode"
	dc.b  0
	dc.b  0
.align 2
	bra intexc

/* A-opcode exception handler
 */
aopc:
	trap #newl
	trap #msg
.ascii "A opcode"
	dc.b  0
	dc.b  0
.align 2
	bra.s intexc

/* F-opcode exception handler
 */
fopc:
	trap #newl
	trap #msg
.ascii "F opcode"
	dc.b  0
	dc.b  0
.align 2

/* Generic exception handler
 */
intexc:
	trap #newl
	trap #msg
.ascii "Status register "
	dc.b  0
.align 2
	move.w (a7), d1
	bsr prthex4
	trap #newl
	trap #msg
.ascii "Program Counter "
	dc.b  0
.align 2
	move.l 2(a7), d1
	bsr prthex8
	bra recover

/* General block copy routine */
blkmov:
	tst.l d1
	beq dummy
	cmp.l a0, a1
	beq dummy
	movem.l a0/a1/d1/d2, -(a7)
	move.l a0, d0
	move.l a1, d2
	eor.b d2, d0
	swap d0
	cmp.l a0, a1
	shi d0
	bcs.s blkmov1
	add.l d1, a0
	add.l d1, a1
blkmov1:
	btst #16, d0
	bne blkmovb
	tst.b d0
	bmi blkmov2
	btst #0, d2
	beq.s blkmov3
	move.b (a0)+, (a1)+
	subq.l #1, d1
	beq blkmovend
blkmov3:
	move.l d1, d2
	move.l d1, d0
	lsr.l #6, d0
	and.w #0b111100, d1
	lsr.w #1, d1
	neg.w d1
	jmp blkmov5-.-2(pc, d1.w)
blkmov4:
	move.l (a0)+, (a1)+
	move.l (a0)+, (a1)+
	move.l (a0)+, (a1)+
	move.l (a0)+, (a1)+
	move.l (a0)+, (a1)+
	move.l (a0)+, (a1)+
	move.l (a0)+, (a1)+
	move.l (a0)+, (a1)+
	move.l (a0)+, (a1)+
	move.l (a0)+, (a1)+
	move.l (a0)+, (a1)+
	move.l (a0)+, (a1)+
	move.l (a0)+, (a1)+
	move.l (a0)+, (a1)+
	move.l (a0)+, (a1)+
	move.l (a0)+, (a1)+
blkmov5:
	dbra d0, blkmov4
	btst #1, d2
	beq.s blkmov6
	move.w (a0)+, (a1)+
blkmov6:
	lsr.b #1, d2
	bcc.s blkmovend
	move.b (a0)+, (a1)+
blkmovend:
	movem.l (a7)+, a0/a1/d1/d2
	rts
blkmov2:
	move.l a0, d2
	lsr.b #1, d2
	bcc.s blkmov8
	move.b -(a0), -(a1)
	subq.l #1, d1
	beq blkmovend
blkmov8:
	move.l d1, d2
	move.l d1, d0
	lsr.l #6, d0
	and.w #0b111100, d1
	lsr.w #1, d1
	neg.w d1
	jmp blkmov10-.-2(pc, d1.w)
blkmov9:
	move.l -(a0), -(a1)
	move.l -(a0), -(a1)
	move.l -(a0), -(a1)
	move.l -(a0), -(a1)
	move.l -(a0), -(a1)
	move.l -(a0), -(a1)
	move.l -(a0), -(a1)
	move.l -(a0), -(a1)
	move.l -(a0), -(a1)
	move.l -(a0), -(a1)
	move.l -(a0), -(a1)
	move.l -(a0), -(a1)
	move.l -(a0), -(a1)
	move.l -(a0), -(a1)
	move.l -(a0), -(a1)
	move.l -(a0), -(a1)
blkmov10:
	dbra d0, blkmov9
	btst #1, d2
	beq.s blkmov11
	move.w -(a0), -(a1)
blkmov11:
	lsr.b #1, d2
	bcc blkmovend
	move.b -(a0), -(a1)
	bra blkmovend
blkmovb:
	move.l d1, d2
	and.w #0b1111, d1
	add.w d1, d1
	neg.w d1
	lsr.l #4, d2
	tst.b d0
	bmi.s blkmov12
	jmp blkmov14-.-2(pc, d1.w)
blkmov13:
	move.b (a0)+, (a1)+
	move.b (a0)+, (a1)+
	move.b (a0)+, (a1)+
	move.b (a0)+, (a1)+
	move.b (a0)+, (a1)+
	move.b (a0)+, (a1)+
	move.b (a0)+, (a1)+
	move.b (a0)+, (a1)+
	move.b (a0)+, (a1)+
	move.b (a0)+, (a1)+
	move.b (a0)+, (a1)+
	move.b (a0)+, (a1)+
	move.b (a0)+, (a1)+
	move.b (a0)+, (a1)+
	move.b (a0)+, (a1)+
	move.b (a0)+, (a1)+
blkmov14:
	dbra d2, blkmov13
	sub.l #0x10000, d2
	bcc.s blkmov13
	bra blkmovend
blkmov12:
	jmp blkmov16-.-2(pc, d1.w)
blkmov15:
	move.b -(a0), -(a1)
	move.b -(a0), -(a1)
	move.b -(a0), -(a1)
	move.b -(a0), -(a1)
	move.b -(a0), -(a1)
	move.b -(a0), -(a1)
	move.b -(a0), -(a1)
	move.b -(a0), -(a1)
	move.b -(a0), -(a1)
	move.b -(a0), -(a1)
	move.b -(a0), -(a1)
	move.b -(a0), -(a1)
	move.b -(a0), -(a1)
	move.b -(a0), -(a1)
	move.b -(a0), -(a1)
	move.b -(a0), -(a1)
blkmov16:
	dbra d2, blkmov15
	sub.l #0x10000, d2
	bcc.s blkmov15
	bra blkmovend

/* Input line from keyboard */
line:
	movem.l d1/d2/d3/d4/a0, -(a7)
	clr.w d2
	move.l d0, d3
	move.l d0, d4
	lsr.l #8, d3
	swap d4
line1:
	trap #rdch
	bcs.s linesc
	cmp.b #21, d0
	beq.s linecnc
	cmp.b #127, d0
	beq.s linedel
	cmp.b d3, d0
	bcs.s line2
	cmp.b d4, d0
	bhi.s line2
	cmp.w d2, d1
	bhi.s line3
	moveq #7, d0
	bra.s line2
line3:
	move.b d0, (a0)+
	addq.w #1, d2
line2:
	trap #asci
	cmp.b #13, d0
	bne.s line1
	move.b d0, (a0)+
linesc:
	scs 29(a7)
	movem.l (a7)+, a0/d1/d2/d3/d4
	rts
line4:
	moveq #127, d0
	trap #wrch
	subq.l #1, a0
linecnc:
	dbra d2, line4
	clr.w d2
	bra.s line1
linedel:
	tst.w d2
	beq.s line1
	subq.w #1, d2
	subq.l #1, a0
	trap #wrch
	bra.s line1

/* Input line from screen
 * Scrapes the current line from the screen into a buffer
 */
sline:
	movem.l d1/d2/a0/a1, -(a7)
sline1:
	trap #rdch
	scc esc
	bcs.s sline1
	clr.b esc
	trap #asci
	cmp.b #13, d0
	bne.s sline1
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
	lea wtab-.-2(pc), a1
	clr.w d1
	moveq #11, d0
	trap #wrch
sline2:
	move.w #0x8700, d0
	trap #gen
	lsr.w #8, d0
	move.b d0, (a0)+
	addq.b #1, d1
	swap d0
	and.w #0xff, d0
	move.b 0(a1, d0.w), d2
	moveq #9, d0
	trap #wrch
	cmp.b d2, d1
	bcs.s sline2
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
	moveq #32, d0
	subq.w #1, d1
sline3:
	cmp.b -(a0), d0
	dbne d1, sline3
	beq.s sline4
	addq.l #1, a0
sline4:
	move.b #13, (a0)
	movem.l (a7)+, d1/d2/a0/a1
	rts
wtab:
	dc.b 80
	dc.b  40
	dc.b  20
	dc.b  80
	dc.b  40
	dc.b  20
	dc.b  40
	dc.b  40
.align 2

/* Match a string against a keyword table
 */
match:
	movem.l d1/d2/d3/d4/a0, -(a7)
	clr.w d1
	move.w d0, d2
	lsr.w #8, d2
	move.l d0, d3
	swap d3
match1:
	move.l 24(a7), a6
match2:
	move.b (a6)+, d0
	move.b (a0)+, d4
	eor.b d0, d4
	and.b d2, d4
	beq.s match2
	add.b d4, d4
	beq.s matchf
	cmp.b d3, d0
	beq.s matchf
	subq.l #1, a0
match3:
	tst.b (a0)+
	bpl.s match3
	addq.w #1, d1
	cmp.b #255, (a0)
	bne.s match1
	clr.b 29(a7)
	bra.s match4
matchf:
	move.l a6, 24(a7)
	st 29(a7)
match4:
	move.w d1, d0
	movem.l (a7)+, d1/d2/d3/d4/a0
	rts

/* Read escape flag */
readesc:
	tst.b esc
	smi 9(a7)
	rts

/* Clear escape flag */
clresc:
	clr.b esc
	rts

/* Read reset reason */
rdreset:
	move.b reset, d0
	rts

/* Read last error number */
rderrnm:
	move.b errnum, d0
	rts

/* Read OSHWM */
rdoshwm:
	move.l oshwm, a0
	rts

/* Read restart vector */
rdrstrt:
	move.l restart, a0
	rts

/* Write restart vector */
strstrt:
	move.l a0, restart
	rts

/* Convert a 32 bit hex value from ASCII to binary */
inhex32:
	moveq #-1, d0
	bra.s inhex

/* Convert a 16 bit hex value from ASCII to binary */
inhex16:
	move.l #0xffff, d0
	bra.s inhex

/* Convert an 8 bit hex value from ASCII to binary */
inhex8:
	move.l #0xff, d0
inhex:
	movem.l d1/d2, -(a7)
	move.l d0, d2
	moveq #0, d1
	move.l a0, -(a7)
inhexc:
	move.b (a0)+, d0
	sub.b #48, d0
	bcs.s inhexend
	cmp.b #10, d0
	bcs.s inhexd
	subq.b #7, d0
	cmp.b #10, d0
	bcs.s inhexend
inhexd:
	cmp.b #16, d0
	bcc.s inhexend
	cmp.l #0x10000000, d1
	bcc.s toobig
	asl.l #4, d1
	or.b d0, d1
	cmp.l d2, d1
	bhi.s toobig
	bra.s inhexc
inhexend:
	subq.l #1, a0
	cmp.l (a7)+, a0
	beq.s invhex
	move.l d1, d0
	movem.l (a7)+, d1/d2
	rts
invhex:
	trap #err
	dc.b 28
.ascii  "Bad hex"
	dc.b  0
	dc.b  0
.align 2
toobig:
	trap #err
	dc.b 20
.ascii  "Too big"
	dc.b  0
	dc.b  0
.align 2

flvdu:
	moveq #12, d0
	bra outch

/* Handlers for OSCLI commands processed locally */
clitab:
	dc.b 0xaf
.ascii  "LOA"
	dc.b  0xc4
.ascii  "SAV"
	dc.b  0xc5
.ascii  "RU"
	dc.b  0xce
	dc.b  0xff
	dc.b  0
.align 2
clijt:
	dc.w run-clijt
	dc.w loadcmd-clijt
	dc.w savcmd-clijt
	dc.w run-clijt

nospc:
	move.b (a6)+, d0
	cmp.b #32, d0
	beq.s nospc
	move.b -(a6), d0
	rts

/* *LOAD command handler */
loadcmd:
	movem.l a1/a2/a3, -(a7)
	sub.l a1, a1
	bsr nospc
	move.l a6, -(a7)
ldcmd2:
	move.b (a6)+, d0
	cmp.b #13, d0
	beq.s ldcmd3
	cmp.b #32, d0
	bne.s ldcmd2
	bsr nospc
	move.l a6, a0
	bsr inhex32
	move.l d0, a1
ldcmd3:
	move.l (a7)+, a0
	moveq #1, d0
	trap #file
	movem.l (a7)+, a1/a2/a3
	rts

/* *RUN command handler */
run:
	bsr nospc
	move.l a6, a0
	movem.l a1/a2/a3, -(a7)
	sub.l a1, a1
	moveq #1, d0
	trap #file
	jsr (a3)
	movem.l (a7)+, a1/a2/a3
	rts

badcmd:
	trap #err
	dc.b 254
.ascii  "Bad command"
	dc.b  0
	dc.b  0
.align 2

/* *SAVE command handler */
savcmd:
	bsr nospc
	cmp.b #13, d0
	beq.s badcmd
	movem.l a1/a2/a3, -(a7)
	move.l a6, -(a7)
savcmd1:
	move.b (a6)+, d0
	cmp.b #13, d0
	beq.s badcmd
	cmp.b #32, d0
	bne.s savcmd1
	bsr nospc
	cmp.b #13, d0
	beq.s badcmd
	move.l a6, a0
	bsr inhex32
	move.l d0, a1
	move.l d0, a2
	move.l d0, a3
	move.l a0, a6
	bsr nospc
	cmp.b #13, d0
	beq.s badcmd
	cmp.b #43, d0
	seq -(a7)
	bne.s savcmd3
	addq.l #1, a6
	bsr nospc
savcmd3:
	move.l a6, a0
	bsr inhex32
	move.l d0, d1
	tst.b (a7)+
	bmi.s savcmd4
	sub.l a1, d1
savcmd4:
	move.l a0, a6
	bsr nospc
	cmp.b #13, d0
	beq.s dosav
	move.l a6, a0
	bsr inhex32
	move.l d0, a3
	move.l a0, a6
	bsr nospc
	cmp.b #13, d0
	beq.s dosav
	move.l a6, a0
	bsr inhex32
	move.l d0, a2
dosav:
	move.l (a7)+, a0
	moveq #0, d0
	trap #file
	movem.l (a7)+, a1/a2/a3
	rts
.equ	endprg, .


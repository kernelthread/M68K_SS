/* 68000 Monitor for Electron 2nd processor board
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

.equ    linebuf, 0x1200

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

.equ    monitor_trap, 15
.equ    monitor_trap_vec, 0xBC

    .section .text
    .global START_MCM
    .global monitor_entry

START_MCM:
    trap #monitor_trap              /* Take TRAP to enter monitor from user mode */

monitor_entry:
    move.l 0, a7                    /* reset the stack */
    lea resume-.-2(pc), a0
    moveq #19, d0
    trap #gen                       /* set restart vector */
    lea monitor_entry-.-2(pc), a0
    move.l a0, monitor_trap_vec     /* set up the TRAP entry point */
    lea keydef-.-2(pc), a0          /* set up key definition */
    moveq #4, d0
    trap #gen                       /* OSCLI */
resume:
    trap #newl
prompt:
    moveq #0x2E, d0
    trap #wrch                      /* '.' command prompt */
    lea linebuf, a0
    moveq #11, d0
    trap #gen                       /* read line from screen */
1:
    move.b (a0)+, d0
    cmp.b #0x20, d0                 /* ignore spaces */
    beq.s 1b
    cmp.b #0x2E, d0                 /* ignore . prompt */
    beq.s 1b
    cmp.b #0x0D, d0                 /* blank line? */
    beq.s prompt
    cmp.b #0x2A, d0                 /* Starts with * -> OSCLI */
    beq.s star_cmd
    cmp.b #0x4D, d0                 /* Starts with M = memory dump */
    beq.s mem_dump
    cmp.b #0x3A, d0                 /* Starts with : = memory modification */
    beq.s mem_modify
    cmp.b #0x43, d0                 /* Starts with C = call */
    beq.s call_addr
    cmp.b #0x47, d0                 /* Starts with G = go */
    beq.s goto_addr
    cmp.b #0x54, d0                 /* Starts with T = block transfer */
    beq mem_move
    cmp.b #0x52, d0                 /* Starts with R = read 6502 memory */
    beq read_6502_mem
    cmp.b #0x57, d0                 /* Starts with W = write 6502 memory */
    beq write_6502_mem
    trap #err                       /* Otherwise, unrecognised command */
	dc.b 0
.ascii  "Mistake"
	dc.b  0
.align 2

star_cmd:
    moveq #4, d0
    trap #gen               /* OSCLI */
    bra.s prompt

/* inhex16 = convert 4 digit ASCII hex to binary */
 * inhex32 = convert 8 digit ASCII hex to binary */
 *
 * On entry: A0 points to string to be scanned
 * On return: A0 stepped past initial spaces and number converted
 *            D0.L = converted value
 * Throws error if no valid hex digits present
 */
inhex16:
    moveq #21, d0           /* convert ASCII hex to 16 bit binary */
    bra.s 1f
inhex32:
    moveq #22, d0           /* convert ASCII hex to 32 bit binary */
1:
    cmp.b #0x20, (a0)+      /* skip spaces */
    beq.s 1b
    subq.l #1, a0
    trap #gen               /* convert */
    rts

/* Check D0 is even, throw error if not */
check_even:
    btst #0, d0             /* test bit 0 */
    bne.s address_error     /* if set, error */
    rts

/* C command - call a subroutine at specified address */
call_addr:
    bsr.s inhex32           /* get 32 bit address */
    bsr.s check_even
    move.l d0, a1           /* address into A1 */
    jsr (a1)                /* call the address */
    bra prompt              /* go back to prompt */

/* G command - jump to specified address */
goto_addr:
    bsr.s inhex32           /* get 32 bit address */
    bsr.s check_even
    move.l d0, a1           /* address into A1 */
    jmp (a1)                /* jump to the address */

/* : command - modify memory */
mem_modify:
    bsr.s inhex32           /* get 32 bit address */
    bsr.s check_even
    move.l d0, a1           /* address into A1 */
    moveq #8-1, d1          /* number of words to modify */
1:
    bsr.s inhex16           /* get 16 bit data */
    move.w d0, (a1)+        /* write to memory */
    dbra d1, 1b             /* repeat for 8 words */
    bra prompt              /* go back to prompt */

/* M command - dump memory */
mem_dump:
    bsr.s inhex32           /* get 32 bit start address */
    bsr.s check_even
    move.l d0, a1           /* address into A1 */
    bsr.s inhex32           /* get 32 bit end address */
    move.l d0, a2           /* address into A2 */
mem_dump_1:
    moveq #0x2E, d0         /* Start each line with .: */
    trap #wrch              /* This allows moving the cursor, modifying the dumped values, then pressing RETURN */
    moveq #0x3A, d0         /* The line is then re-executed as a : memory modify command */
    trap #wrch
    move.l a1, d1           /* value to print */
    moveq #9, d0
    trap #gen               /* print 32 bit data as 8 digit hex */
    moveq #8-1, d2          /* number of words to print, -1 for DBRA */
mem_dump_2:
    moveq #0x20, d0         /* space */
    trap #wrch
    move.w (a1)+, d1        /* value to print */
    moveq #8, d0
    trap #gen               /* print 16 bit data as 4 digit hex */
    dbra d2, mem_dump_2     /* repeat for 8 words */
    trap #newl
    moveq #5, d0
    trap #gen               /* check for ESCAPE key */
    cmp.l a2, a1            /* passed end address? */
    bls.s mem_dump_1        /* if not, display another 8 words */
    bra prompt              /* go back to prompt */

/* Throw an "Address error" - used if odd addresses are specified */
address_error:
    trap #err
    dc.b 0
.ascii "Address error"
    dc.b 0
.align 2

/* Get three arguments for a transfer command
 *
 * Syntax accepted is
 *      <8 hex digit base> <8 hex digit end> <8 hex digit dest>
 * OR   <8 hex digit base> + <8 hex digit length> <8 hex digit dest>
 *
 * On return:
 *      D2 = base address
 *      D1 = length (=end-base if + option not used)
 *      D0 = dest
 */
get_xfer_args:
    bsr inhex32             /* get base address */
    move.l d0, d2           /* put it in D2 */
1:
    cmp.b #0x20, (a0)+      /* skip over spaces */
    beq.s 1b
    cmp.b #0x2B, -(a0)      /* if + encountered after any spaces ... */
    seq d1                  /* ... set D1.B=FF else set D1.B=0 */
    bne.s 2f
    addq.l #1, a0           /* if + encountered, skip over it */
2:
    bsr inhex32             /* get end address or length */
    exg d0, d1              /* put it in D1, put indicator of '+' option in D0.B */
    tst.b d0
    bmi.s 3f
    sub.l d2, d1            /* if '+' option not used, calculate length as end - base */
3:
    bra inhex32             /* get dest address and return */

/* T command - memory block copy */
mem_move:
    bsr.s get_xfer_args     /* D1 = length for copy */
    move.l d2, a0           /* A0 = source for copy */
    move.l d0, a1           /* A1 = destination for copy */
    moveq #7, d0
    trap #gen               /* do block copy */
    bra prompt

/* R command - read a block of memory from the 6502 */
read_6502_mem:
    bsr.s get_xfer_args
    cmp.l #0x10000, d2      /* Check base address is in range 0000-FFFF */
    bcc.s bad_addr
    cmp.l #0x10000, d1      /* Check length is in range 0000-FFFF */
    bcc.s bad_addr
    move.w d2, a0           /* A0 = source for block read */
    move.l d0, a1           /* A1 = destination for block read */
    move.w d1, d0           /* D0 = length for block read */
    swap d0                 /* length into upper half of D0 */
    move.w #2, d0
    trap #gen               /* read 6502 memory */
    bra prompt

/* W command - write a block of memory to the 6502 */
write_6502_mem:
    bsr.s get_xfer_args
    cmp.l #0x10000, d0      /* Check destination is in range 0000-FFFF */
    bcc.s bad_addr
    cmp.l #0x10000, d1      /* Check length is in range 0000-FFFF */
    bcc.s bad_addr
    move.w d0, a0           /* A0 = destination for block write */
    move.l d2, a1           /* A1 = source for block write */
    move.w d1, d0           /* D0 = length for block write */
    swap d0                 /* length into upper half of D0 */
    move.w #3, d0
    trap #gen               /* write 6502 memory */
    bra prompt

/* Throw a "Bad address" error - used if 6502 address or length >=64K specified */
bad_addr:
    trap #err
    dc.b 0
    .ascii "Bad address"
    dc.b 0
.align 2

/* OSCLI command issued when monitor starts up
 * Defines F1 key to press RETURN then step to the first data value on the next line of a memory dump
 */
keydef:
    .ascii "KEY1 |M|I|I|I|I|I|I|I|I|I|I"
    dc.b 13

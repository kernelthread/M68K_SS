/* Boot ROM for 68000
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

PIADRA                  = 0xFFFF8020
PIADRB                  = 0xFFFF8024
PIACRA                  = 0xFFFF8022
PIACRB                  = 0xFFFF8026

PIACR_Cx1_ST			= 0x80
PIACR_Cx2_ST			= 0x40
PIACR_Cx2_HIGH			= 0x38
PIACR_Cx2_LOW			= 0x30
PIACR_Cx2_SHORT_STROBE	= 0x28
PIACR_Cx2_LONG_STROBE	= 0x20
PIACR_DDR_VISIBLE		= 0x00
PIACR_PR_VISIBLE		= 0x04
PIACR_Cx1_RISING		= 0x02
PIACR_Cx1_FALLING		= 0x00
PIACR_Cx1_IRQEN			= 0x01

PIACRA_HIGH				= 0x3C
PIACRA_LOW				= 0x34
PIACRA_STROBE			= 0x2C
PIACRB_HIGH				= 0x3C
PIACRB_LOW				= 0x34
PIACRB_STROBE			= 0x2C

INITIAL_SP_LOC          = 0x00
INITIAL_PC_LOC          = 0x04

BOOT_MAGIC_ADDR         = 0x30
RESET_REASON_ADDR       = 0x34
BOOT_MAGIC_VAL          = 0xDB27CC8B
COPIED_CODE_DEST        = 0x80
INITIAL_SP              = 0x100

/******************************************************************************/
    .section .text

    .global START

    .long   INITIAL_SP
    .long   START
START:
    CLR.B       PIACRA                  /* CRA default value */
    CLR.B       PIACRB                  /* CRB default value */
    ST          PIADRB                  /* DDRB=0xFF Port B output */
    CLR.B       PIADRA                  /* DDRA=0x00 Port A input */
    MOVEQ       #PIACR_Cx2_SHORT_STROBE + PIACR_PR_VISIBLE, D0
    MOVE.B      D0, PIACRA              /* CRA=0x2C CA2 short low read strobe, CA1 active low */
    MOVE.B      D0, PIACRB              /* CRB=0x2C CB2 short low read strobe, CB1 active low */
    TST.B       PIADRB                  /* Clear output data read flag */
    CLR.B       PIADRB                  /* Send 0x00 to 6502 */
1:
    TST.B       PIACRB                  /* Wait for it to be read */
    BPL.S       1b
    MOVE.L      #BOOT_MAGIC_VAL, D0
    TST.B       PIADRB                  /* Clear output data read flag */
    TST.B       PIADRA                  /* Clear input data present flag */
    MOVE.B      D0, PIADRB              /* Send 0x8B to 6502 */
1:
    TST.B       PIACRA                  /* Wait for reply */
    BPL.S       1b
    CMP.B       PIADRA, D0              /* Check we received 0x8B in return */
0:
    BNE.S       0b                      /* If not, halt */
1:
    TST.B       PIACRA                  /* Wait for input */
    BPL.S       1b
    MOVE.B      PIADRA, D7              /* Receive reset reason, store in D7 */
    CMP.L       BOOT_MAGIC_ADDR, D0     /* Check if magic value is in RAM */
    SNE         PIADRB                  /* If so, send 0x00 to 6502, else send 0xFF */
    BNE.S       COLD_BOOT               /* Branch if value not present */
WARM_BOOT:
    MOVE.L      INITIAL_SP_LOC, A7      /* Warm start - load SP from 0  */
    MOVE.L      INITIAL_PC_LOC, A6      /* Load first instruction address from 4 */
    JMP         (A6)                    /* Jump back into RAM-resident image */

COLD_BOOT:
    TST.B       PIADRB                  /* Clear output data read flag (NO CHECK!!) */
    LEA         CODE_TO_COPY(PC), A0    /* A0 = address of ROM code to be copied into RAM */
    MOVE.W      #(CODE_TO_COPY_END-CODE_TO_COPY-2)/2, D1    /* Number of words to copy - 1 */
    MOVE.W      #COPIED_CODE_DEST, A1   /* Destination address for copy */
1:
    MOVE.W      (A0), (A1)              /* Copy 16 bits */
    CMP.W       (A0)+, (A1)+            /* Check it copied correctly */
    DBNE        D1, 1b                  /* Repeat until all necessary code copied */
    SNE         PIADRB                  /* If copy successful, send 0x00 to 6502, else send 0xFF */
0:
    BNE.S       0b                      /* Halt if copy failed */
    JMP         COPIED_CODE_DEST        /* Jump into RAM copy of code */

CODE_TO_COPY:
    MOVE.L      A1, D1                  /* First address following copied code */
    ADDQ.L      #2, D1
    AND.B       #0xFC, D1               /* Round up to 4 byte boundary */
    MOVE.L      D1, A1
    MOVEQ       #-1, D1
1:
    MOVE.L      D1, (A1)                /* Write 0xFFFFFFFF to memory */
    ADDQ.L      #1, (A1)                /* Add 1 (reads, adds 1 and writes back to RAM) */
    BNE.S       2f                      /* Branch out if didn't read expected value */
    TST.L       (A1)+                   /* Check location is now 0 */
    BEQ.S       1b                      /* If so, do next address */
    SUBQ.L      #4, A1                  /* A1 contains address after end of RAM */
2:
    MOVE.L      A1, D1                  /* into D1 */
    TST.W       D1                      /* check for multiple of 64K */
    SNE         PIADRB                  /* If not, send 0xFF to 6502, else send 0x00 */
0:
    BNE.S       0b                      /* If not, halt */
    MOVE.L      A1, INITIAL_SP_LOC      /* Store top of RAM address to initial SP */
    MOVE.L      A1, A7                  /* and into SP */
    SWAP        D1                      /* D1.W = RAM size / 64k */
    MOVE.B      D1, PIADRB              /* Send it to 6502 */
    MOVEQ       #0, D1                  /* So that top 24 bits are initialized to 0 */
    BSR.S       READ_BYTE               /* Read byte from 6502 (load address high byte) */
    ASL.W       #8, D1                  /* into D1[8:15] */
    BSR.S       READ_BYTE               /* Read another byte from 6502 into D1[0:7] (load address low byte) */
    MOVE.L      D1, A1                  /* Sign-extended D1 into A1 (load address) */
    MOVE.L      A1, A2                  /* and also into A2 */
    BSR.S       READ_BYTE               /* Read byte from 6502 (byte count high) */
    ASL.W       #8, D1                  /* into D1[8:15] */
    BSR.S       READ_BYTE               /* Read another byte from 6502 into D1[0:7] (byte count low) */
    MOVE.W      D1, D2                  /* Byte count into D2.W */
    SUBQ.W      #1, D2                  /* for DBRA */
1:
    BSR.S       READ_BYTE               /* Read byte from 6502 */
    MOVE.B      D1, (A1)+               /* Store to specified load address and step on address */
    DBRA        D2, 1b
    MOVE.L      A2, INITIAL_PC_LOC      /* Store load address to initial PC */
    MOVE.L      D0, BOOT_MAGIC_ADDR     /* Store magic value so we do a warm start next time */
    MOVE.B      D7, RESET_REASON_ADDR   /* Store reset reason received from 6502 */
    JMP         (A2)                    /* Jump to load address */

READ_BYTE:
    TST.B       PIACRA      /* check for input */
    BPL.S       READ_BYTE   /* loop if none */
    MOVE.B      PIADRA, D1  /* read input byte into D1 */
    RTS
CODE_TO_COPY_END:

    .align 256, 0

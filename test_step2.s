***************************************************************
** test_step2.s : Step 2 UART1 receive-interrupt echo test
***************************************************************

.include "os_defs.s"

***************************************************************
** System stack
***************************************************************
.section .bss
.even
SYS_STK:
    .ds.b 0x4000
.even
SYS_STK_TOP:

***************************************************************
** Initialization
***************************************************************
.section .text
.even
boot:
    move.w #0x2700, %SR
    lea.l SYS_STK_TOP, %SP

    | 1. Set UART1 interrupt vector
    move.l #RECEIVE_TEST, 0x110

    | 2. Initialize interrupt controller
    move.b #0x40, IVR
    move.l #0x00ffffff, IMR

    | 3. Initialize UART1
    move.w #0x0000, USTCNT1
    move.w #0xe108, USTCNT1
    move.w #0x0038, UBAUD1

    | 4. Initialize timer1 (disabled)
    move.w #0x0004, TCTL1

    | 5. Permit UART1 interrupts
    move.l #0x00ff3ffb, IMR

    | 6. CPU interrupt mask level = 0
    move.w #0x2000, %SR

    bra MAIN

***************************************************************
** Main loop
***************************************************************
MAIN:
    bra MAIN

***************************************************************
** Receive interrupt handler
***************************************************************
RECEIVE_TEST:
    move.l %D0, -(%SP)

    move.w URX1, %D0
    andi.w #0x00ff, %D0
    ori.w #0x0800, %D0
    move.w %D0, UTX1

    move.l (%SP)+, %D0
    rte

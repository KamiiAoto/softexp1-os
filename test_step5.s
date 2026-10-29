.include "os_defs.s"       /* 定数定義など */
.include "os_queue.s"      /* キュー関連 (QUEUE_INIT, INQ, OUTQ 等) */
.include "os_uart.s"       /* UART・INTERPUT・PUTSTRING 等 */
.include "os_init.s"
.include "os_interface.s" 


***************************************************************
** 各種レジスタ定義 (Step 1: p.29)
***************************************************************


***************************************************************
** スタック領域の確保 (.bss)
***************************************************************
.section .bss
.even
SYS_STK:
    .ds.b   0x4000
.even
SYS_STK_TOP:

***************************************************************
** テスト用文字列データ (.data, 3.9.2節 p.36)
***************************************************************
.section .data
.even
TDATA1: .ascii "0123456789ABCDEF"
TDATA2: .ascii "klmnopqrstuvwxyz"

***************************************************************
** 初期化ルーチン (boot)
***************************************************************
.section .text
.even
boot:
    move.w  #0x2700, %sr            /* スーパーバイザ & 割り込み禁止 */
    lea.l   SYS_STK_TOP, %sp        /* SSP の設定 */

    * 割り込みコントローラの初期化
    move.b  #0x40, IVR              /* ベクタ基点 = 0x40 + level */
    move.l  #0x00ffffff, IMR        /* 全割り込みマスク */

    * 割り込みベクタの設定 (Level 4 UART1 = ベクタ番号68 = 0x110番地)
    move.l  #uart1_interrupt, 0x110

    * キューの初期化 (Step 0)
    jsr     QUEUE_INIT

    * UART1 の初期化 (送受信有効、送受信割り込みは両方マスク状態: 0xe100)
    move.w  #0x0000, USTCNT1        /* リセット */
    move.w  #0xe100, USTCNT1        /* 8bit, 1stop, パリティなし, 割り込み禁止 */
    move.w  #0x0038, UBAUD1         /* 230400bps (※P30変更箇所) */

    * タイマ関係の初期化
    move.w  #0x0004, TCTL1

    * IMR で UART1 割り込み (Bit 2) を許可
    andi.l  #0xfffffffb, IMR

    bra     MAIN

***************************************************************
** Step 5 動作テスト本体 (3.9.2節 p.36)
***************************************************************
MAIN:
    move.w  #0x2000, %sr            /* スーパーバイザモードのまま走行レベルを 0 に */

    * (1) PUTSTRING(0, #TDATA1, 16) を1回実行
    move.l  #0, %d1                 /* ch = 0 */
    move.l  #TDATA1, %d2            /* p = #TDATA1 */
    move.l  #16, %d3                /* size = 16 */
    jsr     PUTSTRING

    * (2) 数秒間の空ループ処理
    move.l  #0x100000, %d7          /* ループ回数は環境に応じ調整 (例: 0x100000〜0x400000) */
WAIT_LOOP:
    subq.l  #1, %d7
    bne     WAIT_LOOP

    * (3) PUTSTRING(0, #TDATA2, 16) を無限に繰り返し実行
SEND_LOOP:
    move.l  #0, %d1                 /* ch = 0 */
    move.l  #TDATA2, %d2            /* p = #TDATA2 */
    move.l  #16, %d3                /* size = 16 */
    jsr     PUTSTRING
    bra     SEND_LOOP


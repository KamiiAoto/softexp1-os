.include "os_defs.s"       /* 定数定義など */
.include "os_queue.s"      /* キュー関連 (QUEUE_INIT, INQ, OUTQ 等) */
.include "os_uart.s"       /* UART・INTERPUT・PUTSTRING 等 */
.include "os_init.s"
.include "os_interface.s" 


***************************************************************
** 各種レジスタ定義 (Step 1: p.29)
***************************************************************




***************************************************************
** テスト用文字列データ (.data, 3.9.2節 p.36)
***************************************************************
.section .data
.even
TDATA1: .ascii "0123456789ABCDEF"
TDATA2: .ascii "klmnopqrstuvwxyz"


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


/***************************************************************
** test_step5.s : Step 3.9.2 送信制御部の動作テストプログラム
**   - TDATA1 ("0123456789ABCDEF") を PUTSTRING で一度送信
**   - 空ループを挟んだ後、TDATA2 ("klmnopqrstuvwxyz") を繰り返し送信
***************************************************************/

.include "os_defs.s"       /* 必要に応じて定義ファイル等をインクルード */
.include "os_queue.s"      /* キュー関連 (QUEUE_INIT, INQ, OUTQ 等) */
.include "os_uart.s"       /* UART・INTERPUT・PUTSTRING 等 */

.section .data
.even
TDATA1: .ascii "0123456789ABCDEF"
TDATA2: .ascii "klmnopqrstuvwxyz"

.section .text
.global main

main:
    /* 1. すべての割り込みをマスク (走行レベルを 7 に設定) */
    move.w  #0x2700, %SR

    /* 2. 初期化モジュール呼び出し (QUEUE_INIT 等) */
    jsr     QUEUE_INIT

    /* 3. USTCNT1 を操作して送信割り込みをマスクしておく (TXAE = 0) */
    andi.w  #0xFFFE, 0xFFF900

    /* 4. スーパーバイザモードのまま，走行レベルを 0 にし，割り込み許可 */
    /* (※仕様書の手順に合わせて、この後に最初のPUTSTRINGを実行します) */
    move.w  #0x0000, %SR

    /* 5. PUTSTRING(0, #TDATA1, 16) を実行 */
    move.l  #0, %d1                 /* ch = 0 */
    lea.l   TDATA1, %d2             /* p = TDATA1 のアドレス */
    move.l  #16, %d3                /* size = 16 */
    jsr     PUTSTRING

    /* 6. 数秒の空ループ処理を行う (カウンタによるウェイト) */
    move.l  #0x00500000, %d6        /* 適当なウェイト値 (環境に合わせて調整) */
wait_loop:
    subq.l  #1, %d6
    bne     wait_loop

    /* 7. PUTSTRING(0, #TDATA2, 16) を繰り返し実行するループ */
test_repeat_loop:
    move.l  #0, %d1                 /* ch = 0 */
    lea.l   TDATA2, %d2             /* p = TDATA2 のアドレス */
    move.l  #16, %d3                /* size = 16 */
    jsr     PUTSTRING

    /* 繰り返し速度を調整するための軽いウェイト（お好みで調整） */
    move.l  #0x00010000, %d6
repeat_wait:
    subq.l  #1, %d6
    bne     repeat_wait

    bra     test_repeat_loop        /* 無限に繰り返す */

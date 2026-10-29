/***************************************************************
** test_step5.s : Step 3.9.2 送信制御部の動作テストプログラム
**   - TDATA1 ("0123456789ABCDEF") を PUTSTRING で一度送信
**   - 空ループを挟んだ後、TDATA2 ("klmnopqrstuvwxyz") を繰り返し送信
***************************************************************/


.include "os_uart.s"       /* UART・INTERPUT・PUTSTRING 等 */



.section .text
.global main

main:
    /* 1. すべての割り込みをマスク (走行レベルを 7 に設定) */
    move.w  #0x2700, %SR

    /* 2. 初期化モジュール呼び出し (QUEUE_INIT 等) */
    jsr     QUEUE_INIT

    /* 3. USTCNT1 を操作して送信割り込みをマスクしておく (TXAE = 0) */
    andi.w  #0xFFFE, 0xFFF900

    /* 4. 走行レベルを 0 にし、割り込み許可(スーパーバイザーモードは維持ーーー) */
    move.w  #0x2000, %SR

    /* 5. PUTSTRING(0, #TDATA1, 16) を実行 */
    move.l  #0, %d1                 /* ch = 0 (%d1.L) */
    
    /* 修正ポイント: lea はアドレスレジスタ (%a2) で受けてから %d2 に渡す */
    lea.l   TDATA1, %a2             /* p のアドレスを一時的に %a2 へ */
    move.l  %a2, %d2                /* PUTSTRING の仕様に合わせて %d2.L にセット */
    
    move.l  #16, %d3                /* size = 16 (%d3.L) */
    jsr     PUTSTRING

    /* 6. 数秒の空ループ処理を行う (ウェイト) */
    move.l  #0x00500000, %d6        /* 適当なウェイト値 */
wait_loop:
    subq.l  #1, %d6
    bne     wait_loop

    /* 7. PUTSTRING(0, #TDATA2, 16) を繰り返し実行するループ */
test_repeat_loop:
    move.l  #0, %d1                 /* ch = 0 */
    
    /* 同様に TDATA2 のアドレスを %a2 経由で %d2 に渡す */
    lea.l   TDATA2, %a2
    move.l  %a2, %d2
    
    move.l  #16, %d3                /* size = 16 */
    jsr     PUTSTRING

    /* 繰り返し速度を調整するための軽いウェイト */
    move.l  #0x00010000, %d6
repeat_wait:
    subq.l  #1, %d6
    bne     repeat_wait

    bra     test_repeat_loop        /* 無限に繰り返す */





.section .data
.even
TDATA1: .ascii "0123456789ABCDEF"
TDATA2: .ascii "klmnopqrstuvwxyz"

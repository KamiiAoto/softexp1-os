/***************************************************************
** test_step4.s : 送信割り込みおよびOUTQの動作テスト用メイン
**   - キュー1に 'a' と 'b' を交互に計256文字書き込む
**   - 走行レベルを落とし、送信割り込み(TXAE)を許可して自動送信させる
***************************************************************/

.section .text
.global main

main:
    /* 1. すべての割り込みをマスク（走行レベルを 7 に設定） */
    move.w  #0x2700, %sr

    /* 2. キューの初期化（QUEUE_INIT を呼び出し） */
    jsr     QUEUE_INIT

    /* 3. 送信キュー（キュー1）にデータを合計 256 文字書き込む */
    move.l  #1, %d0          /* %d0.L = キュー番号 1 (送信) */
    move.l  #0, %d2          /* ループカウンタ (0 〜 255) */

test_write_loop:
    /* 16文字ごとに 'a' と 'b' を切り替えるための判定 */
    move.l  %d2, %d3
    andi.l  #0x1F, %d3       /* 0 〜 31 の範囲でループする値を作る */
    cmpi.l  #16, %d3
    bge     write_b          /* 16以上なら 'b' を書く */

write_a:
    move.b  #0x61, %d1       /* 'a' (コード 0x61) */
    bra     do_inq

write_b:
    move.b  #0x62, %d1       /* 'b' (コード 0x62) */

do_inq:
    /* INQ(1, data) の呼び出し */
    jsr     INQ

    addq.l  #1, %d2
    cmpi.l  #256, %d2
    blt     test_write_loop

    /* 4. 送信割り込みを許可する (USTCNT1 の TXAEビット = 1) */
    /*    USTCNT1 (0xFFF900) のビット0 (TXAE) を 1 にする */
    ori.w   #0x0001, 0xFFF900

    /* 5. 走行レベルを 0 に落として割り込みを受け付け可能にする */
    move.w  #0x0000, %sr

    /* 6. 無限ループ（あとは割り込み駆動で自動送信される） */
infinite_loop:
    bra     infinite_loop

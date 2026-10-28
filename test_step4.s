.section .text
.global main

main:
    ; 1. すべての割り込みをマスク（走行レベルを 7 に設定）
    move.w  #0x2700, %sr

    ; 2. キューの初期化（QUEUE_INIT を呼び出し）
    jsr     QUEUE_INIT

    ; 3. 送信キュー（キュー1）にデータを合計 256 文字書き込む
    ;    (aを連続16文字、bを連続16文字... を繰り返して計256文字)
    move.l  #1, %d0          ; %d0.L = キュー番号 1 (送信)
    move.l  #0, %d2          ; ループカウンタ (0 〜 255)

test_write_loop:
    ; 16文字ごとに 'a' と 'b' を切り替える判定
    ; d2 を 16 で割った余り、あるいはシンプルに d2 のビットで判定
    move.l  %d2, %d3
    divu.w  #16, %d3         ; 上位16bitに余り、下位16bitに商が入る
    swap    %d3              ; %d3 の下位に余り（0〜15）を移動
    
    ; 余りが 0〜7 なら 'a' (0x61), 8〜15 なら 'b' (0x62) にする例
    ; （※テキストの「aを16文字、bを16文字…」の厳密な繰り返しに合わせます）
    move.l  %d2, %d3
    andi.l  #0x1F, %d3       ; 0〜31 のループ
    cmpi.l  #16, %d3
    bge     write_b          

write_a:
    move.b  #0x61, %d1       ; 'a'
    bra     do_inq
write_b:
    move.b  #0x62, %d1       ; 'b'

do_inq:
    ; INQ(1, data) の呼び出し
    ; (%d0.L = 1, %d1.B = 文字データ)
    jsr     INQ

    addq.l  #1, %d2
    cmpi.l  #256, %d2
    blt     test_write_loop

    ; 4. out を top に、s を 256 に設定する (仕様書の指示)
    ;    ※すでに QUEUE_INIT と INQ で正しく設定されていますが、
    ;      明示的に確認・強制設定する場合はここで操作できます。
    ;      (通常は INQ が自動で s をインクリメントするのでそのままでOK)

    ; 5. 走行レベルを 0 にし、送信割り込みを許可する (USTCNT1 の TXAEビット = 1)
    ;    USTCNT1 (0xFFF900) のビット0 (TXAE) を 1 にする
    ori.w   #0x0001, 0xFFF900

    ; 6. 走行レベルを 0 に落として割り込みを受け付け可能にする
    move.w  #0x0000, %sr

    ; 7. 無限ループにする（あとは割り込み駆動で自動送信される）
infinite_loop:
    bra     infinite_loop

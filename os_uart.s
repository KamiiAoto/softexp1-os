***************************************************************
** os_uart.s : 送受信制御部 (Step 4〜6)
**   担当: 送信 = INTERPUT, PUTSTRING（田邉）
**         受信 = INTERGET, GETSTRING（安森）
**   レビュー: 受信担当（安森）⇔ 送信担当（田邉）
**
**   チャネル引数 ch は本実験では常に 0 (UART1)．付録 C の 2 チャンネル化に
**   備えて，テキストどおり ch を受け取る形で書く (3.8.1 節の注)．
**   レジスタの保存と復元は付録 B.2.3 を参照．
***************************************************************

.section .text
.even

.include "os_defs.s"       /* 定数定義など */
.include "os_queue.s"      /* キュー関連 (QUEUE_INIT, INQ, OUTQ 等) */

***************************************************************
** INTERPUT(ch) : 送信割り込み処理 (Step 4, 3.8.1 節 p.33)
**   【入力】  %D1.L = チャネル ch
**   【戻り値】なし
**   【処理内容】p.33 の (1)〜(5)．キューが空なら送信割り込みをマスク．
**              UTX1 への書き込みでは上位 8bit のヘッダを忘れずに．
***************************************************************
INTERPUT:
	move.w %SR, -(%SP)
	move.w #0x2700, %sr /* 割り込み禁止に */

	movem.l %d0-%d1, -(%sp)
	
    cmpi.l #0, %d1
	bne	INTERPUT_BACK

    move.l #1, %d0
    jsr OUTQ /* 成功不成功はd0へ */
    
    cmpi.l #0, %d0
    beq INTERPUT_MASK

    andi.l #0x000000FF, %d1 /* 下位8bit以外クリア */
    ori.w #0x0800, %d1 /* 上位8ビット制御ビット　フロー制御は行わない */
    move.w %d1, UTX1
    bra INTERPUT_BACK


INTERPUT_MASK:
    andi.w #0xfffb, USTCNT1 /* 最下位ビットのみ0にし他は影響しない */
    bra INTERPUT_BACK
    
INTERPUT_BACK:
	movem.l (%sp)+, %d0-%d1
    move.w (%SP)+, %SR

rts

***************************************************************
** PUTSTRING(ch, p, size) : 送信キューにデータを入れる (Step 5, 3.9.1 節 p.35)
**   【入力】  %D1.L = ch,  %D2.L = 先頭アドレス p,  %D3.L = データ数 size
**   【戻り値】%D0.L = 実際にキューに入れたデータ数 sz
**   【処理内容】p.35 の (1)〜(10)．最後に送信割り込みを許可 (USTCNT1)．
***************************************************************
PUTSTRING:
	move.w %SR, -(%SP)
    movem.l %d2-%d5/%a0-%a1, -(%sp)

    cmpi.l #0, %d1
    bne PUTSTRING_END

    move.l #0, %d4 /* szをd4 */
    movea.l %d2, %a0 /* iをa0 */
    move.l %d3, %d5 /* d5にサイズを保持 */

    cmpi.l #0, %d5 /* sizeが0かどうか */
    beq PUTSTRING_FINISH

PUTSTRING_CHECK:    
    cmp.l %d5, %d4 /* szとsize比較 */
    beq PUTSTRING_ENABLE

    move.l #1, %d0 /* キュー番号 */
    move.b (%a0), %d1 /* 格納データ */
    jsr INQ

    cmpi.l #0, %d0
    beq PUTSTRING_ENABLE

    addq.l #1, %d4
    addq.l #1, %a0

    bra PUTSTRING_CHECK

PUTSTRING_ENABLE:
    ori.w #0x0001, 0xFFF900 /* USTCNT1のbitを1に */

PUTSTRING_FINISH:
    move.l %d4, %d0
    bra PUTSTRING_BACK

PUTSTRING_END:
    move.l #0, %d0

PUTSTRING_BACK:
    movem.l (%sp)+, %d2-%d5/%a0-%a1
    move.w (%SP)+, %SR 
	rts

***************************************************************
** INTERGET(ch, data) : 受信割り込み処理 (Step 6, 3.10.2 節 p.38-39)
**   【入力】  %D1.L = ch,  %D2.B = 受信データ data
**   【戻り値】なし
**   【処理内容】ch = 0 なら INQ(0, data)．
**   【注意】INQ を呼ぶときは ch=%D0.L, data=%D1.B とレジスタがずれる．
***************************************************************
INTERGET:
    movem.l %d0-%d1, -(%sp)             /*作業用レジスタの退避(1) ch ≠ 0 ならば何もせず終了 (終了処理へジャンプ)*/
    cmpi.l  #0, %d1
    bne     INTERGET_EXIT

   /*(2) INQ(0, data) により，受信キュー(0番)に data を格納する*/
    moveq.l #0, %d0                     /*キュー番号 no = 0 → %D0.L*/
    move.b  %d2, %d1                    /*受信データ data → %D1.B (レジスタのずれ調整)*/
    jsr     INQ                         /*INQ の復帰値は無視してよい*/

INTERGET_EXIT:
    movem.l (%sp)+, %d0-%d1             /*退避したレジスタの復元*/
    rts

***************************************************************
** GETSTRING(ch, p, size) : 受信キューからデータを取り出す (Step 6, 3.10.1 節 p.38)
**   【入力】  %D1.L = ch,  %D2.L = 書き込み先アドレス p,  %D3.L = データ数 size
**   【戻り値】%D0.L = 実際に取り出したデータ数 sz
**   【処理内容】p.38 の (1)〜(9)．
***************************************************************
GETSTRING:
    movem.l %d1-%d4/%a0, -(%sp)         /*作業用レジスタの退避 (%D0は戻り値のため退避しない)*/

    /*(1) ch ≠ 0 ならば何もせず終了 (戻り値 0 で終了)*/
    cmpi.l  #0, %d1
    bne     GETSTRING_ERR

    /*(2) sz ← 0 (%D4.L を sz として使用)，i ← p (%A0 を i として使用)*/
    moveq.l #0, %d4                     /*sz = 0*/
    movea.l %d2, %a0                    /*i = p*/

GETSTRING_LOOP:
    /*(3) sz == size ならば (9) へ*/
    cmp.l   %d3, %d4
    beq     GETSTRING_DONE

    /*(4) OUTQ(0, data) により受信キュー(0番)から 8bit データ data を取り出す*/
    moveq.l #0, %d0                     /*キュー番号 no = 0 → %D0.L*/
    jsr     OUTQ                        /*戻り値: %D0.L = 0 or 1, %D1.B = data*/

    /*(5) OUTQ の復帰値 (%D0) が 0 ならば (9) へ*/
    cmpi.l  #0, %d0
    beq     GETSTRING_DONE

    /*(6) アドレス i で始まる領域に data をコピー ＆ (7) sz++, i++*/
    move.b  %d1, (%a0)+                 /*:m[i] = data, i++*/
    addq.l  #1, %d4                     /*sz++*/

    /*(8) (3) へ戻る*/
    bra     GETSTRING_LOOP

GETSTRING_DONE:
    /* (9) %D0 ← sz として終了*/
    move.l  %d4, %d0
    bra     GETSTRING_EXIT

GETSTRING_ERR:
    moveq.l #0, %d0                     /*ch ≠ 0 の場合は 0 を返す*/

GETSTRING_EXIT:
    movem.l (%sp)+, %d1-%d4/%a0         /*退避したレジスタの復元*/
    rts

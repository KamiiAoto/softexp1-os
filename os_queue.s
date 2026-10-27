***************************************************************
** os_queue.s : キュー (Step 0, テキスト 3.4 節 p.24-28)
**   担当: 受信（安森）・送信（田邉）
**   レビュー: 受信担当（安森）⇔ 送信担当（田邉）
**
**   キューは 2 本: 0 番 = 受信 (QNO_RECV)，1 番 = 送信 (QNO_SEND)．各 256 バイト．
**   制御用の変数 (表 3.2): top, bottom, out, in, s
**   スーパーバイザモードで実行される (ユーザモードから直接呼ばないこと)．
***************************************************************

.section .text
.even

***************************************************************
** QUEUE_INIT : 2 本のキューを初期化する (3.4.1 節)
**   【入力】なし   【戻り値】なし
	**   TODO: top/out/in ← データ領域の先頭，bottom ← 末尾，s ← 
***************************************************************
QUEUE_INIT:
	movem.l %a2-%a3, -(%sp)     | 使用するレジスタの退避

    * キュー0 (受信用) の初期化
    lea.l   BF0_START, %a2
    lea.l   BF0_END, %a3
    move.l  %a2, top0
    move.l  %a3, bottom0        | bottom には末尾アドレスを入れる
    move.l  %a2, out0
    move.l  %a2, in0
    move.l  #0, s0

    * キュー1 (送信用) の初期化
    lea.l   BF1_START, %a2
    lea.l   BF1_END, %a3
    move.l  %a2, top1
    move.l  %a3, bottom1
    move.l  %a2, out1
    move.l  %a2, in1
    move.l  #0, s1

	movem.l (%sp)+, %a2-%a3     | レジスタの復帰
	rts

***************************************************************
** INQ(no, data) : 番号 no のキューにデータを 1 つ入れる (3.4.2 節)
**   【入力】  %D0.L = キュー番号 no,  %D1.B = 書き込む 8bit データ
**   【戻り値】%D0.L = 0 (失敗: queue full) / 1 (成功)
**   【処理内容】p.25 の (1)〜(7)．走行レベルの退避・割り込み禁止を忘れずに．
***************************************************************
INQ:
	move.w  %sr, -(%sp)        /*(1)走行レベル(%SR)をa3に退避*/
	movem.l %a0-%a1,-(%sp)
	move.w  #0x2700, %sr    /*(2)割り込み禁止 */
	lea.l Q0_INFO,%a0
	cmpi.l #0,%d0
	beq INQ_CHECK_FULL
	lea.l Q1_INFO,%a0
INQ_CHECK_FULL:	 /*(3) s== 256 でqueue full*/
	cmpi.l  #256, S(%a0)
	beq     INQ_FULL
	movea.l IN(%a0),%a1 /*(4)m[in] = data*/
	move.b %d1, (%a1)
	cmpa.l BOTTOM(%a0), %a1 /*(5)*/
	beq INQ_WRAP
	adda.l #1,%a1
	bra INQ_UPDATE

INQ_WRAP:
	movea.l TOP(%a0), %a1

INQ_UPDATE:	
	move.l %a1,IN(%a0)  /*更新したin保存*/

	addi.l #1, S(%a0)  /*(6)*/
	moveq.l #1,%d0
	bra INQ_BACK

INQ_FULL:
	moveq #0,%d0

INQ_BACK:
	movem.l (%sp)+, %a0-%a1
	move.w (%sp)+,%sr
	rts

***************************************************************
** OUTQ(no, data) : 番号 no のキューからデータを 1 つ取り出す (3.4.2 節)
**   【入力】  %D0.L = キュー番号 no
**   【戻り値】%D0.L = 0 (失敗: queue empty) / 1 (成功)
**             %D1.B = 取り出した 8bit データ
**   【処理内容】p.26 の (1)〜(7)．
***************************************************************
OUTQ:
	move.w %SR, -(%SP)
	movem.l %a0-%a1,-(%sp)
	ori.w #0x2700, %SR

	cmpi.l #0, %d0
	beq	OUTQ_Q0

*キュー1
OUTQ_Q1:
	cmpi.l #0, s1
	beq	OUTQ_EMPTY_OUT1
	
	move.l	out1, %a0
	move.l	(%a0), %d1

	cmp.l	bottom1, %a0
	bne	OUTQ_PLS_OUT1
	move.l	top1, %a0
	bra	OUTQ_UPDATTE_OUT1
OUTQ_PLS_OUT1:
	addq.l	#1, %a0
OUTQ_UPDATTE_OUT1:
	move.l %a0, out1

	subq.l #1, s1
	move.l #1, %d0
	
	bra OUTQ_EXIT
OUTQ_EMPTY_OUT1:
	move.l #0, %d0
	bra OUTQ_EXIT

*キュー0
OUTQ_Q0:
	cmpi.l #0, s0
	beq	OUTQ_EMPTY_OUT0
	
	move.l	out0, %a0
	move.l	(%a0), %d1

	cmp.l	bottom0, %a0
	bne	OUTQ_PLS_OUT0
	move.l	top0, %a0
	bra	OUTQ_UPDATTE_OUT0
OUTQ_PLS_OUT0:
	addq.l	#1, %a0
OUTQ_UPDATTE_OUT0:
	move.l %a0, out0

	subq.l #1, s0
	move.l #1, %d0
	
	bra OUTQ_EXIT
OUTQ_EMPTY_OUT0:
	move.l #0, %d0
	bra OUTQ_EXIT

OUTQ_EXIT:
	move.w (%SP)+, %SR
	movem.l (%sp)+, %a0-%a1
	rts
***************************************************************
** キューの領域 (.bss に .ds で確保する: 3.4.1 節)
***************************************************************
.section .bss
.even

	/*TODO: データ領域 256 バイト × 2 と，変数 top/bottom/out/in/s*/
* キュー0 (受信用: 256バイト)
BF0_START:  .ds.b 255
BF0_END:    .ds.b 1

* キュー1 (送信用: 256バイト)
BF1_START:  .ds.b 255
BF1_END:    .ds.b 1

.even
* キュー0 の制御変数 (先頭から +0, +4, +8, +12, +16 バイト)
Q0_INFO:
top0:       .ds.l 1
bottom0:    .ds.l 1
out0:       .ds.l 1
in0:        .ds.l 1
s0:         .ds.l 1

* キュー1 の制御変数 (Q0_INFO の直後 = +20バイト目から配置)
Q1_INFO:
top1:       .ds.l 1
bottom1:    .ds.l 1
out1:       .ds.l 1
in1:        .ds.l 1
s1:         .ds.l 1

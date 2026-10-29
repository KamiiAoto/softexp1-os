***************************************************************
** test_interface.s : SYSCALL_IF と TIMER1_INTERRUPT の動作確認 (Step 7, 8)
**   UART (送受信) を使わず，LED の表示だけで確認する．
**   アセンブル: m68k-as -t 400 test_interface.s
**
**   確認すること:
**     LED7 : 進み具合
**            '1' MAIN に到達 (ユーザモードへ移行済み)
**            '2' 範囲外の番号 (0, 5, -1) で trap #0 しても戻ってきた
**            '3' RESET_TIMER, SET_TIMER の trap #0 から戻ってきた
**            'E' 割り込みの前後でレジスタが壊れた (TIMER1_INTERRUPT の退避ミス)
**     LED0 : タイマで呼ばれた回数．1 秒ごとに '1' → '5' と変わり，'5' で止まる
**            (止まらなければ RESET_TIMER の trap が効いていない)
**   LED の表示がおかしいときは，付録 A.4.3 で LED への書き込み方を確認すること．
***************************************************************
	.include "os_defs.s"
	.include "os_init.s"
	.include "os_interface.s"
	.include "os_queue.s"
	.include "os_uart.s"
	.include "os_timer.s"

.section .text
.even
MAIN:
	** user_echo.s と同じくユーザモードへ移行してから trap を使う
	move.w	#0x0000, %SR            | USER MODE, LEVEL 0
	lea.l	TI_STK_TOP, %SP         | user stack の設定
	move.b	#'1', LED7
	move.b	#'0', LED0

	******************************
	** (1) 範囲外の番号で trap #0 → 何もせずに戻ってくればよい
	******************************
	move.l	#0, %D0
	trap	#0
	move.l	#5, %D0
	trap	#0
	move.l	#-1, %D0
	trap	#0
	move.b	#'2', LED7

	******************************
	** (2) RESET_TIMER, SET_TIMER をシステムコールで起動
	**     t = 10000 (× 0.1 msec = 1 秒) ごとに TI_TICK を呼ぶ
	******************************
	move.l	#SYSCALL_NUM_RESET_TIMER, %D0
	trap	#0

	move.l	#SYSCALL_NUM_SET_TIMER, %D0
	move.w	#10000, %D1
	move.l	#TI_TICK, %D2
	trap	#0
	move.b	#'3', LED7

	******************************
	** (3) レジスタに決まった値を入れ，割り込みの前後で変わらないか見張る
	**     (%A6 は使わない，%A7 = SP なので見張らない)
	******************************
	move.l	#0x11111111, %D1
	move.l	#0x22222222, %D2
	move.l	#0x33333333, %D3
	move.l	#0x44444444, %D4
	move.l	#0x55555555, %D5
	move.l	#0x66666666, %D6
	move.l	#0x77777777, %D7
	movea.l	#0xa0a0a0a0, %A0
	movea.l	#0xa1a1a1a1, %A1
	movea.l	#0xa2a2a2a2, %A2
	movea.l	#0xa3a3a3a3, %A3
	movea.l	#0xa4a4a4a4, %A4
	movea.l	#0xa5a5a5a5, %A5
TI_CHECK:
	cmpi.l	#0x11111111, %D1
	bne	TI_BROKEN
	cmpi.l	#0x22222222, %D2
	bne	TI_BROKEN
	cmpi.l	#0x33333333, %D3
	bne	TI_BROKEN
	cmpi.l	#0x44444444, %D4
	bne	TI_BROKEN
	cmpi.l	#0x55555555, %D5
	bne	TI_BROKEN
	cmpi.l	#0x66666666, %D6
	bne	TI_BROKEN
	cmpi.l	#0x77777777, %D7
	bne	TI_BROKEN
	cmpa.l	#0xa0a0a0a0, %A0
	bne	TI_BROKEN
	cmpa.l	#0xa1a1a1a1, %A1
	bne	TI_BROKEN
	cmpa.l	#0xa2a2a2a2, %A2
	bne	TI_BROKEN
	cmpa.l	#0xa3a3a3a3, %A3
	bne	TI_BROKEN
	cmpa.l	#0xa4a4a4a4, %A4
	bne	TI_BROKEN
	cmpa.l	#0xa5a5a5a5, %A5
	bne	TI_BROKEN
	bra	TI_CHECK

TI_BROKEN:
	move.b	#'E', LED7
TI_STOP:
	bra	TI_STOP

***************************************************************
** TI_TICK : タイマ割り込みで (CALL_RP から) 呼ばれるルーチン
**   わざとレジスタを退避せずに壊す．TIMER1_INTERRUPT が全レジスタを
**   退避・復帰していれば，MAIN の見張りループは 'E' にならない．
**   5 回目に RESET_TIMER をシステムコールで呼んでタイマを止める．
***************************************************************
TI_TICK:
	addq.w	#1, TI_CNT
	move.w	TI_CNT, %D0
	addi.b	#'0', %D0               | 回数 → 文字 ('1'〜'5')
	move.b	%D0, LED0

	moveq.l	#-1, %D1                | わざとレジスタを壊す
	moveq.l	#-1, %D2
	moveq.l	#-1, %D3
	moveq.l	#-1, %D4
	moveq.l	#-1, %D5
	moveq.l	#-1, %D6
	moveq.l	#-1, %D7
	movea.l	#0, %A0
	movea.l	#0, %A1
	movea.l	#0, %A2
	movea.l	#0, %A3
	movea.l	#0, %A4
	movea.l	#0, %A5

	cmpi.w	#5, TI_CNT              | 5 回呼ばれたらタイマを止める
	bne	TI_TICK_END
	move.l	#SYSCALL_NUM_RESET_TIMER, %D0
	trap	#0
TI_TICK_END:
	rts

****************************************************************
*** 初期値のあるデータ領域
****************************************************************
.section .data
.even
TI_CNT:
	.dc.w	0                       | TI_TICK が呼ばれた回数

****************************************************************
*** 初期値の無いデータ領域
****************************************************************
.section .bss
.even
TI_STK:
	.ds.b	0x4000                  | ユーザスタック領域
	.even
TI_STK_TOP:                             | ユーザスタック領域の最後尾

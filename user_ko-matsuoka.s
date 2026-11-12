***************************************************************
** user_ko-matsuoka.s : Step 10 時計(2) hh:mm:ss
**
** 1sごとにTTを呼び出し、TIMEを1s進めて表示
**　23:59:59の次は00:00:00
**
** 精度補正t=10012に変更(40sで約3s進んだため)
** LEDに時間表示
** 時刻を記入してから進める
***************************************************************

****************************************************************
*** プログラム領域
****************************************************************
.section .text
.even
MAIN:
	** 走行モードとレベルの設定 (「ユーザモード」への移行処理)
	move.w	#0x0000, %SR            | USER MODE, LEVEL 0
	lea.l	USR_STK_TOP,%SP         | user stack の設定

	** システムコールによる RESET_TIMER の起動
	move.l	#SYSCALL_NUM_RESET_TIMER,%D0
	trap	#0


	**1文字ずつ6回読んで順に入れる
	move.l #SYSCALL_NUM_PUTSTRING, %D0
	move.l #0, %D1
	move.l #PMSG, %D2
	move.l #19, %D3
	trap #0

	jsr GETKEY
	move.b KEY,TIME+1
	jsr GETKEY
	move.b KEY,TIME+2
	jsr GETKEY
	move.b KEY,TIME+4
	jsr GETKEY
	move.b KEY,TIME+5
	jsr GETKEY
	move.b KEY,TIME+7
	jsr GETKEY
	move.b KEY,TIME+8

	move.l #SYSCALL_NUM_PUTSTRING, %D0
	move.l #0, %D1
	move.l #NL, %D2
	move.l #2, %D3
	trap #0
	

	** 設定した時刻の表示
	move.l #SYSCALL_NUM_PUTSTRING, %D0
	move.l #0, %D1
	move.l #TIME, %D2
	move.l #9, %D3
	trap #0
	
	** システムコールによる SET_TIMER の起動
	move.l	#SYSCALL_NUM_SET_TIMER, %D0
	move.w	#10012, %D1       |修正点
	move.l	#TT, %D2
	trap	#0

LOOP:
	bra LOOP



******************************
* GETKEY: キーを1文字読んでKEYに入れ、画面にも表示する
******************************
GETKEY:
	move.l #SYSCALL_NUM_GETSTRING, %D0
	move.l #0, %D1
	move.l #KEY, %D2
	move.l #1, %D3
	trap #0
	cmpi.l #0, %D0
	beq GETKEY

	move.l #SYSCALL_NUM_PUTSTRING, %D0
	move.l #0, %D1
	move.l #KEY, %D2
	move.l #1, %D3
	trap #0
	rts

	
******************************
* TT:1sごとに呼ばれる
* secondsの1の位から進め、繰り上がりを行う
******************************
TT:
	movem.l	%D0-%D7/%A0-%A6,-(%SP)

	** seconds
	addi.b #1, TIME+8
	cmpi.b #'9', TIME+8
	bls PRINT
	move.b #'0', TIME+8

	addi.b #1, TIME+7
	cmpi.b #'5', TIME+7
	bls PRINT
	move.b #'0', TIME+7


	** minutes
	addi.b #1, TIME+5
	cmpi.b #'9', TIME+5
	bls PRINT
	move.b #'0', TIME+5

	addi.b #1, TIME+4
	cmpi.b #'5', TIME+4
	bls PRINT
	move.b #'0', TIME+4


	** hours
	addi.b #1, TIME+2
	cmpi.b #'9', TIME+2
	bls CHK24
	move.b #'0', TIME+2
	addi.b #1, TIME+1

CHK24:
	cmpi.b #'2', TIME+1
	bne PRINT
	cmpi.b #'4', TIME+2
	bne PRINT
	move.b #'0', TIME+1
	move.b #'0', TIME+2

PRINT:
	** LEDに表示
	move.b TIME+1, LED7
	move.b TIME+2, LED6
	move.b TIME+3, LED5
	move.b TIME+4, LED4
	move.b TIME+5, LED3
	move.b TIME+6, LED2
	move.b TIME+7, LED1
	move.b TIME+8, LED0
	
	** 画面に表示
	move.l #SYSCALL_NUM_PUTSTRING, %D0
	move.l #0, %D1
	move.l #TIME, %D2
	move.l #9, %D3
	trap #0

	movem.l	(%SP)+,%D0-%D7/%A0-%A6
	rts

****************************************************************
*** 初期値のあるデータ領域
****************************************************************
.section .data
TIME:
	.ascii	"\r00:00:00"             | \r: 行頭へ (キャリッジリターン)

PMSG:
	.ascii "set time (hhmmss): "

NL:
	.ascii "\r\n"

KEY:
	.dc.b 0
	
	.even

****************************************************************
*** 初期値の無いデータ領域
****************************************************************
.section .bss
.even
USR_STK:
	.ds.b	0x4000                  | ユーザスタック領域
	.even
USR_STK_TOP:                            | ユーザスタック領域の最後尾

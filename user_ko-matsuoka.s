***************************************************************
** user_ko-matsuoka.s : Step 10 時計(2) hh:mm:ss
**
** 起動時に現在の時刻 hhmmss(6桁)をPCのキーボード上で入力
** SET_TIMERで約1sごとにTTを呼び出し、TIMEを1s進めて画面・LEDに表示
** 23:59:59の次は00:00:00
**
**プログラム作成の流れ
** 実行開始時からの時間をmm:ssで表示
** mm:ssからhh:mm:ssに変更
** 精度補正:t=10000からt=10012に変更
**	(40mで約3s進んだため、t=10000*(1+3/2400)=10012.5を整数に)
** LEDに時間表示
** 時刻を入力してから進める
***************************************************************

****************************************************************
*** プログラム領域
****************************************************************
.section .text
.even
MAIN:
	/*走行モードとレベルの設定(「ユーザモード」への移行処理)*/
	move.w #0x0000, %SR    | USERMODE, LEVEL0
	lea.l USR_STK_TOP, %SP | user stackの設定

	/*システムコールによる RESET_TIMER の起動(時刻入力中はタイマ停止)*/
	move.l #SYSCALL_NUM_RESET_TIMER, %D0
	trap #0

	/*時刻入力メッセージの表示*/
	move.l #SYSCALL_NUM_PUTSTRING, %D0
	move.l #0, %D1    | ch=0
	move.l #PMSG, %D2 | p=PMSGの先頭番地
	move.l #19, %D3   | size=19(メッセージの文字数)
	trap #0

	/*1文字ずつ6回読んでいき、TIMEの数字部分のみに順に入れる*/
	jsr GETKEY
	move.b KEY,TIME+1 | 時10の位
	jsr GETKEY
	move.b KEY,TIME+2 | 時1の位
	jsr GETKEY
	move.b KEY,TIME+4 | 分10の位
	jsr GETKEY
	move.b KEY,TIME+5 | 分1の位
	jsr GETKEY
	move.b KEY,TIME+7 | 秒10の位
	jsr GETKEY
	move.b KEY,TIME+8 | 秒1の位
	
	/*改行して時刻表示を進める*/
	move.l #SYSCALL_NUM_PUTSTRING, %D0
	move.l #0, %D1  | ch=0
	move.l #NL, %D2 | p="\r\n"
	move.l #2, %D3  | size=2
	trap #0
	
	/*設定した時刻の表示*/
	move.l #SYSCALL_NUM_PUTSTRING, %D0
	move.l #0, %D1    | ch=0
	move.l #TIME, %D2 | p="\rhh:mm:ss"
	move.l #9, %D3    | size=9(\r + 8文字)
	trap #0
	
	/*システムコールによる SET_TIMER の起動*/
	move.l	#SYSCALL_NUM_SET_TIMER, %D0
	move.w	#10012, %D1 | t=10012 精度補正済み
	move.l	#TT, %D2    | p=TT (1sごとの処理)
	trap	#0

/*以降、TTで行う*/
LOOP:
	bra LOOP


******************************
* GETKEY: キーを1文字読んでKEYに入れ、画面にも表示する
******************************
GETKEY:
	move.l #SYSCALL_NUM_GETSTRING, %D0
	move.l #0, %D1   | ch=0
	move.l #KEY, %D2 | p=KEY(1バイト)
	move.l #1, %D3   | size=1
	trap #0
	cmpi.l #0, %D0   | %D0=実際に入力された文字数
	beq GETKEY       | 0文字なら読めるまで繰り返し

	/*読んだ文字を画面表示*/
	move.l #SYSCALL_NUM_PUTSTRING, %D0
	move.l #0, %D1   | ch=0
	move.l #KEY, %D2 | p=KEY
	move.l #1, %D3   | size=1
	trap #0
	rts

	
******************************
* TT:約1sごとに呼ばれる
* 秒の1の位から進め、繰り上がりを行う
* 繰り上がりがなくなったらPRINTへ
******************************
TT:
	movem.l	%D0-%D7/%A0-%A6,-(%SP)

	/*seconds*/
	addi.b #1, TIME+8   | 秒1の位 +1
	cmpi.b #'9', TIME+8 | 9以下なら繰り上がりなし
	bls PRINT
	move.b #'0', TIME+8 | 9を超えたら0に戻して繰り上げ

	addi.b #1, TIME+7   | 秒10の位 +1
	cmpi.b #'5', TIME+7 | 5以下なら繰り上がりなし
	bls PRINT
	move.b #'0', TIME+7 | 60sになったら0に戻して分に繰り上げ


	/*minutes*/
	addi.b #1, TIME+5   | 分1の位 +1
	cmpi.b #'9', TIME+5
	bls PRINT
	move.b #'0', TIME+5

	addi.b #1, TIME+4   | 分10の位 +1
	cmpi.b #'5', TIME+4
	bls PRINT
	move.b #'0', TIME+4 | 60mになったら0に戻して時に繰り上げ


	/*hours*/
	addi.b #1, TIME+2   | 時1の位 +1
	cmpi.b #'9', TIME+2
	bls CHK24           | 9以下ならそのまま24時かチェック
	move.b #'0', TIME+2 | 9を超えたら0に戻す
	addi.b #1, TIME+1   | 時10の位 +1

/*24時になったら00時に戻す*/
CHK24:
	cmpi.b #'2', TIME+1
	bne PRINT           | 時10の位が2でなければ表示
	cmpi.b #'4', TIME+2
	bne PRINT           | 時1の位が4でなければ表示
	move.b #'0', TIME+1
	move.b #'0', TIME+2 | 24から00へ

PRINT:
	/*LEDに表示*/
	move.b TIME+1, LED7 | 時10の位
	move.b TIME+2, LED6 | 時1の位
	move.b TIME+3, LED5 | :
	move.b TIME+4, LED4
	move.b TIME+5, LED3
	move.b TIME+6, LED2 | :
	move.b TIME+7, LED1
	move.b TIME+8, LED0
	
	/*画面に表示*/
	move.l #SYSCALL_NUM_PUTSTRING, %D0
	move.l #0, %D1    | ch=0
	move.l #TIME, %D2 | p="\rhhmmss"
	move.l #9, %D3    | size=9
	trap #0

	movem.l	(%SP)+,%D0-%D7/%A0-%A6
	rts


****************************************************************
*** 初期値のあるデータ領域
****************************************************************
.section .data
TIME:
	.ascii	"\r00:00:00"         | \r:行頭へ(キャリッジリターン)

PMSG:
	.ascii "set time (hhmmss): " | 時刻入力メッセージ(19文字)

NL:
	.ascii "\r\n"                | 改行(行頭+次の行)

KEY:
	.dc.b 0                      | GETKEYで読んだ文字を格納
	
	.even

****************************************************************
*** 初期値の無いデータ領域
****************************************************************
.section .bss
.even
USR_STK:
	.ds.b	0x4000 | ユーザスタック領域
	.even
USR_STK_TOP:           | ユーザスタック領域の最後尾

***************************************************************
** os_defs.s : 定数定義（レジスタのアドレス・システムコール番号など）
**   コードは含まない．すべてのエントリファイルの最初に .include する．
**   出典: テキスト 3.5 節 (p.29), 3.13 節 (p.46), 付録 A.4.3 (p.57-58)
***************************************************************

***************
** レジスタ群の先頭
***************
	.equ REGBASE,   0xFFF000          | DMAP を使用．
	.equ IOBASE,    0x00d00000

***************
** 割り込み関係のレジスタ (付録 B.3.1)
***************
	.equ IVR,       REGBASE+0x300     | 割り込みベクタレジスタ
	.equ IMR,       REGBASE+0x304     | 割り込みマスクレジスタ
	.equ ISR,       REGBASE+0x30c     | 割り込みステータスレジスタ
	.equ IPR,       REGBASE+0x310     | 割り込みペンディングレジスタ

***************
** タイマ関係のレジスタ (付録 B.3.2)
***************
	.equ TCTL1,     REGBASE+0x600     | タイマ１コントロールレジスタ
	.equ TPRER1,    REGBASE+0x602     | タイマ１プリスケーラレジスタ
	.equ TCMP1,     REGBASE+0x604     | タイマ１コンペアレジスタ
	.equ TCN1,      REGBASE+0x608     | タイマ１カウンタレジスタ
	.equ TSTAT1,    REGBASE+0x60a     | タイマ１ステータスレジスタ

***************
** UART1（送受信）関係のレジスタ (付録 B.3.3)
***************
	.equ USTCNT1,   REGBASE+0x900     | UART1 ステータス/コントロールレジスタ
	.equ UBAUD1,    REGBASE+0x902     | UART1 ボーコントロールレジスタ
	.equ URX1,      REGBASE+0x904     | UART1 受信レジスタ
	.equ UTX1,      REGBASE+0x906     | UART1 送信レジスタ

***************
** LED・スイッチ (付録 A.4.3)
***************
	.equ LED7,      IOBASE+0x000002f  | ボード搭載の LED 用レジスタ
	.equ LED6,      IOBASE+0x000002d  | 左から LED7 〜 LED0
	.equ LED5,      IOBASE+0x000002b
	.equ LED4,      IOBASE+0x0000029
	.equ LED3,      IOBASE+0x000003f
	.equ LED2,      IOBASE+0x000003d
	.equ LED1,      IOBASE+0x000003b
	.equ LED0,      IOBASE+0x0000039
	.equ PUSHSW,    0xFFF419          | 押しボタンスイッチ（下位 4bit，押すと 0）
	.equ TOGGLESW,  0xD00041          | トグルスイッチ 8 個

***************
** システムコール番号 (3.12.1 節 p.44)
***************
	.equ SYSCALL_NUM_GETSTRING,   1
	.equ SYSCALL_NUM_PUTSTRING,   2
	.equ SYSCALL_NUM_RESET_TIMER, 3
	.equ SYSCALL_NUM_SET_TIMER,   4

***************
** キュー番号 (3.4.1 節 p.24: 受信 = 0 番，送信 = 1 番)
***************
	.equ QNO_RECV,  0
	.equ QNO_SEND,  1

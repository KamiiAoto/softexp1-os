***************************************************************
** test_step0_queue.s : キューの正常動作の確認 (Step 0, テキスト 3.4.3 節 p.26-28)
**   担当: 受信・送信担当
**
**   エミュレータ (m68k-emu / BSVC) で実行する．
**   BSVC には内蔵デバイスが無いので，os_init.s の boot は使わない
**   (デバイスレジスタに触るとバスエラーになる)．ここに専用の start を書く．
**
**   アセンブル: m68k-as -t 400 test_step0_queue.s
**   実行: m68k-emu で .abs を読み込み，PC = 0x400 にして実行．
**         領域のアドレスは .LIS ファイルで調べる．
***************************************************************
	.include "os_defs.s"

.section .bss
.even
TEST_STK:
	.ds.b	0x1000
	.even
TEST_STK_TOP:

.section .text
.even
start:
	move.w	#0x2700,%SR             | スーパーバイザモード (INQ/OUTQ は %SR を操作する)
	lea.l	TEST_STK_TOP,%SP
	jsr	QUEUE_INIT

	** TODO: p.26-28 の確認手順を実装する
	**   %A0 = INQ に渡すデータの領域   (move.b (%A0)+,%D1)
	**   %A1 = INQ の戻り値を置く領域    (move.l %D0,(%A1)+)
	**   %A2 = OUTQ で取り出したデータ   (move.b %D1,(%A2)+)
	**   %A3 = OUTQ の戻り値を置く領域   (move.l %D0,(%A3)+)
	**   手順3: INQ 128 回 → OUTQ 129 回
	**   手順4: INQ 257 回 → OUTQ 257 回
	**   手順5: 両方のキュー (no = 0, 1) で確認
	**   手順6: キュー領域の前後が書き換わっていないか確認

	stop	#0x2700

	.include "os_queue.s"

.section .data
.even
	| TODO: テスト用のデータ領域 (サイズはキューサイズ以上: p.26 の注意)

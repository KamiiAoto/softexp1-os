***************************************************************
** main_echo.s : 簡易 OS + Step 9 エコーバックプログラム（班の最終成果物）
**   アセンブル: m68k-as -t 400 main_echo.s
**   提出用 1 ファイル化: sh tools/bundle.sh main_echo.s simple_os.s  (→ dist/simple_os.s)
**
**   .include の順番に注意:
**     os_defs.s (定数) → os_init.s (boot を 0x400 番地に置く) → その他
***************************************************************
	.include "os_defs.s"
	.include "os_init.s"
	.include "user_echo.s"
	.include "os_interface.s"
	.include "os_queue.s"
	.include "os_uart.s"
	.include "os_timer.s"

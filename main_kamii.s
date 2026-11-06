***************************************************************
** main_kamii.s : 簡易 OS + Step 10 個人課題（四則演算が可能な電卓）
**   アセンブル: m68k-as -t 400 main_kamii.s
**   提出用 1 ファイル化: sh tools/bundle.sh main_kamii.s kamii.s  (→ kamii.s)
**
**   main_echo.s の user_echo.s を user_kamii.s に差し替えたもの．
**   .include の順番に注意:
**     os_defs.s (定数) → os_init.s (boot を 0x400 番地に置く) → その他
***************************************************************
	.include "os_defs.s"
	.include "os_init.s"
	.include "user_kamii.s"
	.include "os_interface.s"
	.include "os_queue.s"
	.include "os_uart.s"
	.include "os_timer.s"

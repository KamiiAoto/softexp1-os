***************************************************************
** main_ko-matsuoka.s : 簡易 OS + Step 10 時計(2)
**
**   .include の順番に注意:
**     os_defs.s (定数) → os_init.s (boot を 0x400 番地に置く) → その他
***************************************************************
	.include "os_defs.s"
	.include "os_init.s"
	.include "user_ko-matsuoka2.s"
	.include "os_interface.s"
	.include "os_queue.s"
	.include "os_uart.s"
	.include "os_timer.s"

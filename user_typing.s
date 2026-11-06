* Type Practice (2) - user program
* Easy: 1.0 sec/char, Normal: 0.5 sec/char, Hard: 0.25 sec/char

.section .text
.even
MAIN:
    move.w #0x0000, %SR
    lea.l TG_USR_STK_TOP, %SP

TG_MENU_START:
    move.l #SYSCALL_NUM_RESET_TIMER, %D0
    trap #0
    clr.w TG_ELAPSED
    clr.w TG_TIME_LIMIT
    clr.b TG_TIME_UP
    clr.b TG_WORD_DONE

    * メニューに戻ったときの残り入力を破棄
TG_CLEAR_INPUT:
    move.l #SYSCALL_NUM_GETSTRING, %D0
    moveq #0, %D1
    move.l #TG_INPUT_BUF, %D2
    moveq #1, %D3
    trap #0
    tst.l %D0
    bne TG_CLEAR_INPUT

    lea.l TG_MENU, %A2
    move.l #TG_MENU_END-TG_MENU, %D3
    jsr TG_PRINT

TG_LEVEL_SELECT:
    move.l #SYSCALL_NUM_GETSTRING, %D0
    moveq #0, %D1
    move.l #TG_INPUT_BUF, %D2
    moveq #1, %D3
    trap #0
    tst.l %D0
    beq TG_LEVEL_SELECT

    move.b TG_INPUT_BUF, %D4
    cmp.b #'1', %D4
    beq TG_EASY
    cmp.b #'2', %D4
    beq TG_NORMAL
    cmp.b #'3', %D4
    bne TG_LEVEL_SELECT
    move.w #1, TG_TICKS_PER_CHAR
    bra TG_START

TG_EASY:
    move.w #4, TG_TICKS_PER_CHAR
    bra TG_START
TG_NORMAL:
    move.w #2, TG_TICKS_PER_CHAR

TG_START:
    lea.l TG_WORD_TABLE, %A1

TG_NEXT_WORD:
    move.l (%A1), %D4
    tst.l %D4
    beq TG_GAME_COMPLETE
    movea.l %D4, %A0

    * 文字数を数える
    movea.l %A0, %A2
    moveq #0, %D5
TG_COUNT:
    tst.b (%A2)
    beq TG_COUNT_END
    addq.l #1, %D5
    addq.l #1, %A2
    bra TG_COUNT
TG_COUNT_END:
    move.l %D5, %D4
    mulu.w TG_TICKS_PER_CHAR, %D4
    move.w %D4, TG_TIME_LIMIT
    clr.w TG_ELAPSED
    clr.b TG_TIME_UP
    clr.b TG_WORD_DONE

    * 前の単語で残った入力を捨てる
TG_DRAIN:
    move.l #SYSCALL_NUM_GETSTRING, %D0
    moveq #0, %D1
    move.l #TG_INPUT_BUF, %D2
    moveq #1, %D3
    trap #0
    tst.l %D0
    beq TG_DRAIN_END
    cmpi.b #0x1b, TG_INPUT_BUF
    beq TG_MENU_START
    bra TG_DRAIN
TG_DRAIN_END:

    * 問題の単語を表示
    lea.l TG_WORD_LABEL, %A2
    move.l #TG_WORD_LABEL_END-TG_WORD_LABEL, %D3
    jsr TG_PRINT
    movea.l %A0, %A2
    move.l %D5, %D3
    jsr TG_PRINT
    lea.l TG_PROMPT, %A2
    move.l #TG_PROMPT_END-TG_PROMPT, %D3
    jsr TG_PRINT

    * 0.25秒ごとに割り込ませる
    move.l #SYSCALL_NUM_SET_TIMER, %D0
    move.w #2500, %D1
    move.l #TG_TIMER_TICK, %D2
    trap #0

TG_INPUT_AGAIN:
    tst.b TG_TIME_UP
    bne TG_WORD_END
    tst.b TG_WORD_DONE
    bne TG_WAIT_NEXT

    move.l #SYSCALL_NUM_GETSTRING, %D0
    moveq #0, %D1
    move.l #TG_INPUT_BUF, %D2
    moveq #1, %D3
    trap #0
    tst.l %D0
    beq TG_INPUT_AGAIN
    cmpi.b #0x1b, TG_INPUT_BUF     | ESCでメニューへ
    beq TG_MENU_START
    tst.b TG_TIME_UP
    bne TG_WORD_END

    move.b TG_INPUT_BUF, %D2
    cmp.b (%A0), %D2
    bne TG_INPUT_AGAIN

    * 正しい文字だけ表示
    lea.l TG_INPUT_BUF, %A2
    moveq #1, %D3
    jsr TG_PRINT
    addq.l #1, %A0
    tst.b (%A0)
    bne TG_INPUT_AGAIN
    move.b #1, TG_WORD_DONE

TG_WAIT_NEXT:
    tst.b TG_TIME_UP
    bne TG_WORD_END
    * 入力完了後の待機中もESCを受け付ける
    move.l #SYSCALL_NUM_GETSTRING, %D0
    moveq #0, %D1
    move.l #TG_INPUT_BUF, %D2
    moveq #1, %D3
    trap #0
    tst.l %D0
    beq TG_WAIT_NEXT
    cmpi.b #0x1b, TG_INPUT_BUF
    beq TG_MENU_START
    bra TG_WAIT_NEXT

TG_WORD_END:
    move.l #SYSCALL_NUM_RESET_TIMER, %D0
    trap #0
    tst.b TG_WORD_DONE
    beq TG_FAILED

    lea.l TG_SUCCESS, %A2
    move.l #TG_SUCCESS_END-TG_SUCCESS, %D3
    jsr TG_PRINT
    bra TG_ADVANCE

TG_FAILED:
    lea.l TG_TIMEOUT_MSG, %A2
    move.l #TG_TIMEOUT_MSG_END-TG_TIMEOUT_MSG, %D3
    jsr TG_PRINT

TG_ADVANCE:
    addq.l #4, %A1
    bra TG_NEXT_WORD

TG_GAME_COMPLETE:
    lea.l TG_FINISHED, %A2
    move.l #TG_FINISHED_END-TG_FINISHED, %D3
    jsr TG_PRINT
    bra TG_MENU_START

* A2: 表示文字列のアドレス, D3: 文字数
TG_PRINT:
    move.l #SYSCALL_NUM_PUTSTRING, %D0
    moveq #0, %D1
    move.l %A2, %D2
    trap #0
    rts

TG_TIMER_TICK:
    move.l %D4, -(%SP)
    addq.w #1, TG_ELAPSED
    move.w TG_ELAPSED, %D4
    cmp.w TG_TIME_LIMIT, %D4
    blt TG_TIMER_END
    move.b #1, TG_TIME_UP
TG_TIMER_END:
    move.l (%SP)+, %D4
    rts

.section .data
.even
TG_WORD_TABLE:
    .dc.l TG_WORD1, TG_WORD2, TG_WORD3, TG_WORD4, TG_WORD5
    .dc.l TG_WORD6, TG_WORD7, TG_WORD8, TG_WORD9, TG_WORD10
    .dc.l TG_WORD11, TG_WORD12, TG_WORD13, TG_WORD14, TG_WORD15
    .dc.l TG_WORD16, TG_WORD17, TG_WORD18, TG_WORD19, TG_WORD20
    .dc.l TG_WORD21, TG_WORD22, TG_WORD23, TG_WORD24, TG_WORD25
    .dc.l TG_WORD26, TG_WORD27, TG_WORD28, TG_WORD29, TG_WORD30
    .dc.l 0

TG_WORD1:
    .ascii "APPLE"
    .dc.b 0
TG_WORD2:
    .ascii "BANANA"
    .dc.b 0
TG_WORD3:
    .ascii "COMPUTER"
    .dc.b 0
TG_WORD4:
    .ascii "CAT"
    .dc.b 0
TG_WORD5:
    .ascii "DOG"
    .dc.b 0
TG_WORD6:
    .ascii "HOUSE"
    .dc.b 0
TG_WORD7:
    .ascii "WATER"
    .dc.b 0
TG_WORD8:
    .ascii "MUSIC"
    .dc.b 0
TG_WORD9:
    .ascii "TRAIN"
    .dc.b 0
TG_WORD10:
    .ascii "ORANGE"
    .dc.b 0
TG_WORD11:
    .ascii "PENCIL"
    .dc.b 0
TG_WORD12:
    .ascii "FLOWER"
    .dc.b 0
TG_WORD13:
    .ascii "SCHOOL"
    .dc.b 0
TG_WORD14:
    .ascii "WINDOW"
    .dc.b 0
TG_WORD15:
    .ascii "PLANET"
    .dc.b 0
TG_WORD16:
    .ascii "FOREST"
    .dc.b 0
TG_WORD17:
    .ascii "GARDEN"
    .dc.b 0
TG_WORD18:
    .ascii "CAMERA"
    .dc.b 0
TG_WORD19:
    .ascii "MARKET"
    .dc.b 0
TG_WORD20:
    .ascii "ROCKET"
    .dc.b 0
TG_WORD21:
    .ascii "ENGINE"
    .dc.b 0
TG_WORD22:
    .ascii "CIRCUIT"
    .dc.b 0
TG_WORD23:
    .ascii "NETWORK"
    .dc.b 0
TG_WORD24:
    .ascii "KEYBOARD"
    .dc.b 0
TG_WORD25:
    .ascii "SOFTWARE"
    .dc.b 0
TG_WORD26:
    .ascii "LANGUAGE"
    .dc.b 0
TG_WORD27:
    .ascii "ELEPHANT"
    .dc.b 0
TG_WORD28:
    .ascii "MOUNTAIN"
    .dc.b 0
TG_WORD29:
    .ascii "ALGORITHM"
    .dc.b 0
TG_WORD30:
    .ascii "INFORMATION"
    .dc.b 0

TG_MENU:
    .ascii "\r\nSELECT LEVEL (1:EASY 2:NORMAL 3:HARD) > "
TG_MENU_END:
TG_WORD_LABEL:
    .ascii "\r\nWORD: "
TG_WORD_LABEL_END:
TG_PROMPT:
    .ascii "\r\nTYPE (ESC: MENU) > "
TG_PROMPT_END:
TG_SUCCESS:
    .ascii "\r\nOK\r\n"
TG_SUCCESS_END:
TG_TIMEOUT_MSG:
    .ascii "\r\nTIME UP\r\n"
TG_TIMEOUT_MSG_END:
TG_FINISHED:
    .ascii "\r\nGAME COMPLETE (30 WORDS)\r\n"
TG_FINISHED_END:

.even
TG_TICKS_PER_CHAR:
    .dc.w 0
TG_ELAPSED:
    .dc.w 0
TG_TIME_LIMIT:
    .dc.w 0
TG_TIME_UP:
    .dc.b 0
TG_WORD_DONE:
    .dc.b 0

.section .bss
.even
TG_INPUT_BUF:
    .ds.b 1
.even
TG_USR_STK:
    .ds.b 0x4000
.even
TG_USR_STK_TOP:

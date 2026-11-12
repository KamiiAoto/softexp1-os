***************************************************************
** user_kamii.s : Step 10 個人課題「13. 四則演算が可能な電卓」
**
** 【第 1 段階: 基本】 2 つの数の四則演算
**   入力例:  12+34 [Enter]   →  表示:  = 46
**            7/0   [Enter]   →  表示:  Error: divide by zero
**   - 数は 0 以上の整数（複数桁）．演算子は + - * / の 4 つ．
**   - 入力の数（オペランド）は 0〜32767 とする（16 ビットに収まる範囲）．
**     → muls.w（16×16→32 ビット）と divs.w（32÷16 ビット）がそのまま使える．
**   - 結果は 32 ビット符号付き．引き算で負になることがあるので，表示は負の数にも対応する．
**   - わり算は整数の商だけ表示する（余りは捨てる）．
**
** 【第 2 段階: 負の数】 オペランドに負の数を書けるようにする
**   入力例:  -5+3  [Enter]   →  表示:  = -2
**            5*-3  [Enter]   →  表示:  = -15
**            5--3  [Enter]   →  表示:  = 8
**            --3   [Enter]   →  表示:  Error: syntax
**   - 数の先頭に '-' を 1 つだけ付けられる（"--3" のように 2 つ以上はエラー）．
**   - 演算子は MAIN_LOOP が 1 文字読むので，"5-3" の '-' は演算子，
**     "5--3" の 2 つ目の '-' は符号，と自然に区別できる．
**   - 入力の数は -32767〜32767 とする．
**     → -32768 を許すと -32768 / -1 の商 32768 が 16 ビットに収まらず，
**       divs.w がオーバーフローする（V フラグ）ので，範囲から外す．
**     → muls.w と divs.w は符号付きなので，CALC は変えなくてよい．
**
** 【第 3 段階: 3 つ以上の数と優先順位】
**   入力例:  1+2*3       [Enter]   →  表示:  = 7
**            10-4-3      [Enter]   →  表示:  = 3        （左から計算する）
**            2*-3+10/4   [Enter]   →  表示:  = -4       （-6 + 2）
**            1000*1000   [Enter]   →  表示:  = 1000000  （結果は 16 ビットを超えてよい）
**            200*200*2   [Enter]   →  表示:  Error: overflow
**            1+          [Enter]   →  表示:  Error: syntax
**            3 4         [Enter]   →  表示:  Error: syntax
**   - * と / を + と - より先に計算する．同じ強さの演算子は左から計算する．
**   - 再帰下降で式を読む．式を 3 つの階層に分け，それぞれをルーチンにする．
**       EXPR   = TERM   { (+ か -) TERM }      … 足し算・引き算の並び
**       TERM   = FACTOR { (* か /) FACTOR }    … 掛け算・割り算の並び
**       FACTOR = 符号付きの数                   … PARSE_SNUM
**     EXPR が TERM を，TERM が FACTOR を呼ぶので，* と / が先に計算される．
**     第 4 段階のかっこは FACTOR に「'(' なら EXPR を呼ぶ」を足すだけで済む．
**   - 途中の結果は 32 ビット符号付き．ただし muls.w と divs.w は 16 ビットの数しか
**     扱えないので，次のときは「Error: overflow」にする（CALC の戻り値 3）．
**       *     : 2 つの数のどちらかが 16 ビット（-32768〜32767）に収まらない
**       /     : 割る数が 16 ビットに収まらない，または divs.w の後に V フラグが立った
**               （商が 16 ビットに収まらない．-32768 / -1 もここで引っかかる）
**       + -   : add.l / sub.l の後に V フラグが立った（32 ビットを超えた）
**     → 200*200*2 は，途中の 40000 が 16 ビットに収まらないので overflow になる．
**   - EXPR / TERM / FACTOR の戻り値 %D0 は CALC とそろえる．
**       1 成功 / 0 0 で割った / 2 書き方がおかしい（syntax）/ 3 オーバーフロー
**     エラーが出たら，その先は読まずに %D0 をそのまま呼び出し元へ返す．
**
** 【このあと足す予定】 かっこ・BackSpace
**
** 【全体の流れ】（第 3 段階）
**   MAIN_LOOP:
**     (1) プロンプト "> " を表示する                       … PUTS
**     (2) 1 行読む（打った文字を表示しながら LINE_BUF に）  … READ_LINE
**     (3) LINE_BUF の先頭から式を 1 つ読んで計算する       … EXPR
**     (4) %D0 が 1 でなければ，番号に合ったエラーメッセージを表示して MAIN_LOOP へ
**           0 → MSG_ERR_DIV0 / 2 → MSG_ERR_SYNTAX / 3 → MSG_ERR_OVERFLOW
**     (5) 行の終わり（0）まで来ているか確かめる（"3 4" や "1+2)" のように
**         余計な文字が残っていれば syntax エラー）
**     (6) "= " と結果を表示して改行する                    … PUTS, PRINT_NUM
**     (7) MAIN_LOOP に戻る
**   （第 1・2 段階の「数を読む → 演算子を読む → 数を読む → CALC」は EXPR の中に移る）
**
** 【レジスタの決まり】
**   - 引数と戻り値は各ルーチンの先頭に書いたレジスタで渡す．
**   - 戻り値に使うレジスタ以外は，ルーチンの中で movem.l で退避・復元する．
**   - システムコール（trap #0）は %D0〜%D3 を使うので，呼ぶ前後に注意する．
***************************************************************

****************************************************************
*** プログラム領域
****************************************************************
.section .text
.even
MAIN:
	** 走行モードとレベルの設定（ユーザモードへの移行）． user_echo.s と同じ．
	move.w	#0x0000, %SR            | USER MODE, LEVEL 0
	lea.l	USR_STK_TOP,%SP         | user stack の設定
MAIN_LOOP:
	lea.l	MSG_PROMPT, %a0 		| (1)
	jsr 	PUTS
	jsr 	READ_LINE
	lea.l 	LINE_BUF, %a0			| (2)
	jsr 	EXPR					| (3)
	cmpi.l 	#0, %d0					| (4)
	beq 	DIV0_ERR
	cmpi.l 	#2, %d0
	beq 	SYNTAX_ERR
	cmpi.l 	#3, %d0
	beq 	OVERFLOW_ERR
	cmpi.b 	#0, (%a0)				| (5)
	bne 	SYNTAX_ERR
	lea.l 	MSG_EQUAL, %a0			| (6)
	jsr 	PUTS
	jsr 	PRINT_NUM
	lea.l  	MSG_CRLF, %a0
	jsr 	PUTS				
	bra		MAIN_LOOP				| (7)
SYNTAX_ERR:
	lea.l 	MSG_ERR_SYNTAX, %a0
	jsr 	PUTS
	bra 	MAIN_LOOP
DIV0_ERR:
	lea.l 	MSG_ERR_DIV0, %a0
	jsr 	PUTS
	bra 	MAIN_LOOP
OVERFLOW_ERR:
	lea.l 	MSG_ERR_OVERFLOW, %a0
	jsr		PUTS
	bra 	MAIN_LOOP
***************************************************************
** GETCHAR : 1 文字受け取るまで待つ
**   【入力】なし
**   【戻り値】%D1.B = 受け取った文字
**   【ヒント】GETSTRING は入力がなければすぐ 0 を返す．
**             %D3 = 1（1 バイト）で呼び，戻り値 %D0 が 1 になるまで繰り返す．
**             バッファには CHAR_BUF（1 バイト）を使う．
***************************************************************
GETCHAR:
	movem.l	%d0/%d2/%d3, -(%sp)
GETCHAR_LOOP:
	move.l	#SYSCALL_NUM_GETSTRING, %d0
	move.l	#0, %d1               | ch   = 0
	move.l	#CHAR_BUF, %d2        | p    = #CHAR_BUF
	move.l	#1, %d3               | size = 1
	trap	#0
	cmpi.l	#1, %d0
	beq		GETCHAR_END
	bra	GETCHAR_LOOP
GETCHAR_END:
	move.b 	CHAR_BUF, %d1
	movem.l	(%sp)+, %d0/%d2/%d3
	rts

***************************************************************
** PUTCHAR : 1 文字表示する
**   【入力】%D1.B = 表示する文字
**   【戻り値】なし（レジスタはすべて保存する）
**   【ヒント】CHAR_BUF に文字を書き，PUTSTRING を %D3 = 1 で呼ぶ．
**             送信キューがいっぱいだと 0 が返るので，1 が返るまで繰り返す．
***************************************************************
PUTCHAR:
	movem.l	%d0-%d3, -(%sp)
	move.b 	%d1, CHAR_BUF
PUTCHAR_LOOP:
	moveq.l #1, %d3
	move.l	#SYSCALL_NUM_PUTSTRING, %d0
	move.l	#0, %d1                 | ch = 0
	move.l	#CHAR_BUF,%d2                | p  = #BUF
	trap	#0
	cmpi.l	#1, %d0
	beq 	PUTCHAR_END
	bra		PUTCHAR_LOOP
PUTCHAR_END:
	movem.l	(%sp)+, %d0-%d3
	rts

***************************************************************
** PUTS : 0 で終わる文字列を表示する
**   【入力】%A0 = 文字列の先頭
**   【戻り値】なし（レジスタはすべて保存する）
**   【ヒント】0 が出てくるまで 1 文字ずつ PUTCHAR を呼ぶ．
***************************************************************
PUTS:
	movem.l	%d1/%a0, -(%sp)
PUTS_LOOP:
	move.b	(%a0)+, %d1
	cmpi.b	#0, %d1
	beq		PUTS_END
	jsr		PUTCHAR
	bra		PUTS_LOOP
PUTS_END:
	movem.l	(%sp)+, %d1/%a0
	rts

***************************************************************
** READ_LINE : 1 行読んで LINE_BUF に入れる
**   【入力】なし
**   【戻り値】LINE_BUF に入力した文字列（最後に 0 を付ける）
**   【ヒント】
**     - GETCHAR で 1 文字ずつ受け取り，PUTCHAR でそのまま表示する（エコーバック）．
**     - '\r'（Enter, 0x0d）が来たら終わり．"\r\n" を表示して改行する．
**     - LINE_BUF の大きさ（LINE_MAX）を超えて書き込まない．
***************************************************************
READ_LINE:
	movem.l %d1-%d2/%a0, -(%sp)
	lea.l 	LINE_BUF, %a0
	move.b 	#0, %d2
READ_LINE_LOOP:
	jsr 	GETCHAR					| %d1 = 打たれた文字
	cmpi.b 	#0x0d, %d1
	beq 	READ_LINE_END
	cmp.b 	#LINE_MAX-1, %d2
	bcc 	READ_LINE_LOOP 	
	move.b 	%d1, (%a0)+
	addq.b 	#1, %d2
	jsr		PUTCHAR					| 打った文字を画面に返す
	bra 	READ_LINE_LOOP
READ_LINE_END:
	move.b 	#0, (%a0)
	lea.l 	MSG_CRLF, %a0
	jsr 	PUTS
	movem.l (%sp)+, %d1-%d2/%a0
	rts

***************************************************************
** PARSE_NUM : 数字の列を数値に直す
**   【入力】%A0 = 読み始める位置
**   【戻り値】%D0.L = 1 成功 / 0 失敗（数字が 1 つもない，または 32767 を超えた）
**             %D1.L = 読んだ数値
**             %A0   = 数字の次の文字を指すように進める
**   【ヒント】値 = 値 × 10 + (文字 − '0') を，'0'〜'9' 以外が来るまで繰り返す．
***************************************************************
PARSE_NUM:
	/* d2: 桁数のカウンタ */
	movem.l %d2-%d3, -(%sp)
	move.l 	#0, %d1
	move.l 	#0, %d2
PARSE_NUM_LOOP:
	move.l 	#0, %d3
	move.b 	(%a0), %d3
	cmpi.l 	#'0', %d3
	bcs 	PARSE_NUM_END
	cmpi.l  #'9', %d3
	bhi		PARSE_NUM_END
	sub.l 	#'0', %d3
	mulu.w	#0x0a, %d1
	add.l 	%d3, %d1
	cmpi.l	#32767, %d1
	bhi 	PARSE_NUM_FAIL 
	addq.l 	#1, %a0
	addq.l 	#1, %d2
	bra 	PARSE_NUM_LOOP
PARSE_NUM_END:
	cmp.l 	#0, %d2
	beq 	PARSE_NUM_FAIL
	move.l	#1, %d0
	movem.l (%sp)+, %d2-%d3
	rts
PARSE_NUM_FAIL:
	move.l	#0, %d0
	movem.l (%sp)+, %d2-%d3
	rts

***************************************************************
** PARSE_SNUM : 符号付きの数（先頭に '-' が 1 つ付いてもよい）を数値に直す
**   【入力】%A0 = 読み始める位置
**   【戻り値】%D0.L = 1 成功 / 0 失敗（'-' の後に数字がない，または 32767 を超えた）
**             %D1.L = 読んだ数値（-32767〜32767）
**             %A0   = 数字の次の文字を指すように進める
**   【ヒント】
**     - (%A0) が '-' なら「負」の印を覚えておき，%A0 を 1 つ進める．
**       （印は %D0〜%D1 以外のレジスタに置き，movem.l で退避・復元する）
**     - そのあと PARSE_NUM を呼ぶ．失敗（%D0 = 0）ならそのまま失敗を返す．
**       → "--3" は 2 つ目の '-' で PARSE_NUM が失敗するので，自然にエラーになる．
**     - 「負」の印があれば neg.l %D1 で符号を反転する．
**     - PARSE_NUM は変更せずにそのまま使う．
***************************************************************
PARSE_SNUM:
	movem.l %d2, -(%sp)
	moveq 	#0, %d2
	cmp.b 	#'-', (%a0)
	bne		PARSE_SNUM_LOOP
	addq	#1, %a0
	moveq 	#1, %d2
PARSE_SNUM_LOOP:
	jsr 	PARSE_NUM
	cmpi.l	#1, %d2
	bne 	PARSE_SNUM_END
	neg.l 	%d1
PARSE_SNUM_END:
	movem.l (%sp)+, %d2
	rts

***************************************************************
** EXPR : 足し算・引き算の並び（TERM { (+ か -) TERM }）を読んで計算する
**   【入力】%A0 = 読み始める位置
**   【戻り値】%D0.L = 1 成功 / 0 0 で割った / 2 syntax / 3 オーバーフロー
**             %D1.L = 計算結果（成功のとき）
**             %A0   = 読み終わった位置（式の次の文字）を指すように進める
**   【ヒント】
**     - まず TERM を呼ぶ．%D0 が 1 でなければそのまま返す．
**       成功したら %D1 を「左の値」として別のレジスタに取っておく．
**     - ループ: (%A0) が '+' か '-' なら
**         演算子を覚えて %A0 を 1 つ進める → TERM を呼ぶ（失敗ならそのまま返す）
**         → CALC で「左の値 演算子 TERM の値」を計算する（失敗ならそのまま返す）
**         → 結果を新しい「左の値」にしてループの先頭へ．
**       '+' でも '-' でもなければループを抜け，「左の値」を %D1 に入れて成功を返す．
**       （その文字が正しいかどうかは呼び出し元が調べる．ここでは読まない）
**     - 「左の値」と「演算子」はルーチンの中のレジスタに置き，movem.l で退避・復元する．
**       TERM や CALC を呼ぶと %D0〜%D3 は書き換わるので，それ以外のレジスタを使うとよい．
**       第 4 段階では EXPR が（FACTOR を通して）自分自身を呼ぶので，ここを守ること．
***************************************************************
EXPR:
	movem.l %d2-%d4, -(%sp)
	jsr 	TERM
	cmpi.l 	#1, %d0
	bne 	EXPR_END
EXPR_LOOP1:
	cmpi.b 	#'+', (%a0)
	beq 	EXPRLOOP2
	cmpi.b 	#'-', (%a0)
	beq 	EXPRLOOP2
	bra 	EXPR_END
EXPRLOOP2:
	move.l 	%d1, %d4 		| 上書き対策
	move.b 	(%a0)+, %d3
	jsr 	TERM
	cmpi.l 	#1, %d0
	bne 	EXPR_END
	move.l 	%d1, %d2
	move.l 	%d4, %d1
	jsr CALC
	cmpi.l 	#1, %d0
	bne 	EXPR_END
	bra 	EXPR_LOOP1
EXPR_END:
	movem.l (%sp)+, %d2-%d4
	rts

***************************************************************
** TERM : 掛け算・割り算の並び（FACTOR { (* か /) FACTOR }）を読んで計算する
**   【入力】%A0 = 読み始める位置
**   【戻り値】%D0.L = 1 成功 / 0 0 で割った / 2 syntax / 3 オーバーフロー
**             %D1.L = 計算結果（成功のとき）
**             %A0   = 読み終わった位置を指すように進める
**   【ヒント】
**     - EXPR と同じ形．TERM → FACTOR，'+' '-' → '*' '/' に読み替えればよい．
**     - "2*-3" の '-' は FACTOR（PARSE_SNUM）が符号として読むので，
**       TERM は '*' の直後をそのまま FACTOR に任せればよい．
***************************************************************
TERM:
	movem.l %d2-%d4, -(%sp)
	jsr 	FACTOR
	cmpi.l 	#1, %d0
	bne 	TERM_END
TERM_LOOP1:
	cmpi.b 	#'*', (%a0)
	beq 	TERMLOOP2
	cmpi.b 	#'/', (%a0)
	beq 	TERMLOOP2
	bra 	TERM_END
TERMLOOP2:
	move.l 	%d1, %d4 		| 上書き対策
	move.b 	(%a0)+, %d3
	jsr 	FACTOR
	cmpi.l 	#1, %d0
	bne 	TERM_END
	move.l 	%d1, %d2
	move.l 	%d4, %d1
	jsr CALC
	cmpi.l 	#1, %d0
	bne 	TERM_END
	bra 	TERM_LOOP1
TERM_END:
	movem.l (%sp)+, %d2-%d4
	rts

***************************************************************
** FACTOR : 1 つの数を読む（第 4 段階でかっこを足す場所）
**   【入力】%A0 = 読み始める位置
**   【戻り値】%D0.L = 1 成功 / 2 syntax
**             %D1.L = 読んだ数値（成功のとき）
**             %A0   = 読み終わった位置を指すように進める
**   【ヒント】
**     - PARSE_SNUM を呼ぶだけ．ただし PARSE_SNUM は失敗すると %D0 = 0 を返すので，
**       EXPR / TERM の決まり（0 は「0 で割った」）に合わせて 2 に読み替える．
***************************************************************
FACTOR:
	cmpi.b 	#'(', (%a0)
	bne		FACTOR_LOOP
	addq 	#1, %a0
	jsr 	EXPR
	cmpi.l  #1, %d0
	bne 	FACTOR_END
	cmpi.b 	#')', (%a0)
	bne 	FACTOR_SYNTAX
	addq 	#1, %a0
	bra 	FACTOR_END
FACTOR_LOOP:
	jsr 	PARSE_SNUM
	cmpi	#1, %d0
	beq 	FACTOR_END
	bra 	FACTOR_SYNTAX
FACTOR_END:
	rts
FACTOR_SYNTAX:
	moveq 	#2, %d0
	rts

***************************************************************
** CALC : 四則演算をする
**   【入力】%D1.L = 1 つ目の数，%D2.L = 2 つ目の数，%D3.B = 演算子の文字
**   【戻り値】%D0.L = 1 成功 / 0 失敗（0 で割ろうとした）/ 2 演算子が違う
**                     / 3 オーバーフロー（第 3 段階で追加）
**             %D1.L = 計算結果（32 ビット符号付き）
**   【ヒント】
**     - '*' は muls.w，'/' は divs.w を使う．
**     - divs.w の結果は下位 16 ビットが商，上位 16 ビットが余り．
**       商だけ使うときは ext.l で 32 ビットに広げる．
**     - 割る数が 0 だと例外が起きるので，divs.w の前に必ず調べる．
**   【第 3 段階で足すこと: オーバーフローを調べて %D0 = 3 を返す】
**     - 32 ビットの数 x が 16 ビットに収まるかの調べ方:
**         下位 16 ビットだけ別のレジスタにコピーして ext.l で 32 ビットに広げ，
**         元の x と cmp.l で比べる．同じなら収まっている．
**     - '*' : muls.w の前に，%D1 と %D2 の両方が 16 ビットに収まるか調べる．
**             （両方収まっていれば，muls.w の結果は必ず 32 ビットに収まる）
**     - '/' : divs.w の前に，%D2 が 16 ビットに収まるか調べる（%D1 は 32 ビットのままでよい <-why?）．
**             divs.w の直後に bvs で V フラグを調べる．V が立ったときは
**             %D1 は書き換わっていない（商が 16 ビットに収まらなかった）．
**     - '+' '-' : add.l / sub.l の直後に bvs で V フラグを調べる．
**     - 0 で割る検査と overflow の検査の順番は，0 で割る検査を先にする
**       （0 は 16 ビットに収まるので，どちらが先でも結果は同じだが，読みやすさのため）．
***************************************************************
CALC:
	cmpi.b 	#'+', %d3
	beq		CALC_ADD
	cmpi.b 	#'-', %d3
	beq		CALC_SUB
	cmpi.b 	#'*', %d3
	beq		CALC_MUL
	cmpi.b 	#'/', %d3
	beq		CALC_DIV
	bra 	CALC_FAIL
CALC_ADD:
	add.l 	%d2, %d1
	bvs 	CALC_OVERFLOW
	bra 	CALC_END
CALC_SUB:
	sub.l 	%d2, %d1
	bvs 	CALC_OVERFLOW
	bra 	CALC_END
CALC_MUL:
	move.w 	%d1, %d0
	ext.l 	%d0
	cmp.l 	%d0, %d1
	bne 	CALC_OVERFLOW
	move.w 	%d2, %d0
	ext.l 	%d0
	cmp.l 	%d0, %d2
	bne 	CALC_OVERFLOW
	muls.w 	%d2, %d1
	bra 	CALC_END
CALC_DIV:
	cmp.l 	#0, %d2
	beq 	CALC_DIV0
	move.w 	%d2, %d0
	ext.l 	%d0
	cmp.l 	%d0, %d2
	bne 	CALC_OVERFLOW
	divs.w 	%d2, %d1
	bvs 	CALC_OVERFLOW
	ext.l 	%d1			| 上位のあまりを消す
	bra 	CALC_END
CALC_FAIL:
	move.l 	#2, %d0
	rts
CALC_DIV0:
	move.l 	#0, %d0
	rts
CALC_OVERFLOW:
	move.l 	#3, %d0
	rts
CALC_END:
	move.l 	#1, %d0
	rts

***************************************************************
** PRINT_NUM : 32 ビット符号付きの数を 10 進数で表示する
**   【入力】%D1.L = 表示する数
**   【戻り値】なし（レジスタはすべて保存する）
**   【ヒント】
**     - 負なら '-' を表示して neg.l で正にする．
**     - 10 で割った余りが 1 の位．余りを '0' を足した文字にして NUM_BUF に後ろから詰め，
**       商が 0 になるまで繰り返す．最後に NUM_BUF の詰めた所から PUTS する．
**     - 注意: divu.w は 32÷16 で，商が 16 ビットに収まらないと失敗する（V フラグ）．
**       32 ビットの数を 10 で割るには，上位 16 ビットと下位 16 ビットに分けて
**       2 回 divu.w する（上位の余りを下位の割り算に持ち越す）．
***************************************************************
PRINT_NUM:
		movem.l	%d0-%d3/%a0, -(%sp)
		cmp.l	#0, %d1
		bpl 	PRINT_NUM_POS
		move.l 	%d1, %d3
		move.b 	#'-', %d1
		jsr PUTCHAR
		move.l 	%d3, %d1
		neg.l 	%d1
PRINT_NUM_POS:
		lea.l	NUM_BUF+NUM_LEN, %a0
		clr.b 	-(%a0)
PRINT_NUM_LOOP:
		/* d0: 0x0a, d1: 入力, d2: 余り*/
		swap    %d1          	| d1 = L : H
		move.w 	#0x0a, %d0
        moveq   #0, %d2
        move.w  %d1, %d2       	| d2 = 0 : H
        divu.w  %d0, %d2       	| d2 = r1 : qH   (H ÷ D)
        move.w  %d2, %d1       	| d1 = L : qH
        swap    %d1          	| d1 = qH : L
        move.w  %d1,%d2       	| d2 = r1 : L    (= r1*65536 + L)
        divu.w  %d0, %d2       	| d2 = r2 : qL
        move.w  %d2, %d1       	| d1 = qH : qL  ← 商
        swap    %d2          	| d2.w = r2     ← 余り
        
		addi.b 	#'0', %d2
		move.b 	%d2, -(%a0)
        
		/*（商が 0 でなければ PRINT_NUM_LOOP へ）*/
		cmp.l 	#0, %d1
		bne 	PRINT_NUM_LOOP

        /*（%a0 から PUTS）                  ← 詰めた先頭から表示 */
        jsr PUTS
		
		movem.l (%sp)+, %d0-%d3/%a0
        rts

****************************************************************
*** 初期値のあるデータ領域
****************************************************************
.section .data
MSG_PROMPT:
	.ascii	"> \0"
MSG_EQUAL:
	.ascii	"= \0"
MSG_CRLF:
	.ascii	"\r\n\0"
MSG_ERR_SYNTAX:
	.ascii	"Error: syntax\r\n\0"
MSG_ERR_DIV0:
	.ascii	"Error: divide by zero\r\n\0"
MSG_ERR_OVERFLOW:
	.ascii	"Error: overflow\r\n\0"
	.even

****************************************************************
*** 初期値の無いデータ領域
****************************************************************
	.equ	LINE_MAX, 64            | 1 行の最大文字数（0 を含む）
	.equ	NUM_LEN,  12            | -2147483648 の 11 文字 + 0

.section .bss
CHAR_BUF:
	.ds.b	1                       | GETCHAR / PUTCHAR 用の 1 文字
	.even
LINE_BUF:
	.ds.b	LINE_MAX                | 入力した 1 行
	.even
NUM_BUF:
	.ds.b	NUM_LEN                 | PRINT_NUM で数を文字にするための作業領域
	.even
USR_STK:
	.ds.b	0x4000                  | ユーザスタック領域
	.even
USR_STK_TOP:                            | ユーザスタック領域の最後尾

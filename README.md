# ソフトウェア実験Ⅰ 簡易 OS（班リポジトリ）

68000 互換 CPU（MC68VZ328）ボード上で動く簡易 OS とエコーバックプログラムを班で開発するためのリポジトリ。
仕様はすべて「ソフトウェア実験I テキスト」に従う（ページ番号はテキストの印刷ページ）。

## メンバーと担当（表 3.1 p.22，5 人班）

| 担当 | 名前 | 主なファイル | レビュー担当 |
|---|---|---|---|
| 初期化 | | `os_init.s`, `os_interface.s`, `main_echo.s` | タイマ |
| 初期化 | | `os_init.s`, `os_interface.s` | タイマ |
| タイマ | | `os_timer.s` | 初期化 |
| 受信 | | `os_queue.s`, `os_uart.s`（INTERGET, GETSTRING） | 送信 |
| 送信 | | `os_queue.s`, `os_uart.s`（INTERPUT, PUTSTRING） | 受信 |

## ファイル構成

| ファイル | 内容 |
|---|---|
| `os_defs.s` | 定数（レジスタのアドレス，システムコール番号，キュー番号）。コードなし |
| `os_init.s` | boot（初期化ルーチン）。0x400 番地から始まる |
| `os_interface.s` | 送受信・タイマのハードウェア割り込みインタフェース，システムコールインタフェース（rte で戻る） |
| `os_queue.s` | QUEUE_INIT, INQ, OUTQ（Step 0） |
| `os_uart.s` | INTERPUT, PUTSTRING, INTERGET, GETSTRING（Step 4〜6） |
| `os_timer.s` | RESET_TIMER, SET_TIMER, CALL_RP（Step 7） |
| `user_echo.s` | Step 9 のユーザプログラム（MAIN） |
| `main_echo.s` | 班の最終成果物の入口（.include を並べるだけ） |
| `test_step0_queue.s` | Step 0 のキューのテスト（エミュレータ用） |
| `test_step1.s` | Step 1 のテスト。Step N のテストはこれをコピーして `test_stepN.s` を作る |
| `tools/bundle.sh` | .include を展開して提出用の 1 ファイルを作る |

- 入口ファイル（`main_*.s`, `test_*.s`）では `os_defs.s` → `os_init.s` の順に最初に .include する（boot を 0x400 番地に置くため）。
- `os_*.s` の中では .include を使わない。
- 選択課題（Step 10）は各自 `user_<名前>.s`（MAIN を定義）と `main_<名前>.s`（`main_echo.s` の `user_echo.s` を差し替えたもの）を作る。

## ビルドと実行（付録 A）

リポジトリの直下で実行する。

```sh
m68k-as -t 400 main_echo.s      # main_echo.abs と main_echo.LIS ができる
m68k-term                       # C-\ c → xm main_echo.abs → c → 何かキーを押す
m68k-emu                        # エミュレータ（キューのテストなど。内蔵デバイスは動かない）
```

## 提出用の 1 ファイル化（付録 A.6.3.2）

簡易 OS は最終的に 1 ファイルで提出する。

```sh
sh tools/bundle.sh main_echo.s simple_os.s   # dist/simple_os.s ができる
m68k-as -t 400 dist/simple_os.s   # 元と同じようにアセンブルできることを確認
```

## 引数レジスタの規約（テキストの仕様どおり。勝手に変えない）

| ルーチン | 入力 | 戻り値 |
|---|---|---|
| INQ | D0.L = キュー番号, D1.B = データ | D0.L = 0 失敗 / 1 成功 |
| OUTQ | D0.L = キュー番号 | D0.L = 0 / 1, D1.B = データ |
| INTERPUT | D1.L = ch | なし |
| INTERGET | D1.L = ch, D2.B = データ | なし |
| PUTSTRING | D1.L = ch, D2.L = p, D3.L = size | D0.L = 書き込んだ数 |
| GETSTRING | D1.L = ch, D2.L = p, D3.L = size | D0.L = 読み出した数 |
| RESET_TIMER | なし | なし |
| SET_TIMER | D1.W = t, D2.L = p | なし |
| システムコール（trap #0） | D0.L = 番号（1 GET, 2 PUT, 3 RESET_TIMER, 4 SET_TIMER）, D1〜 = 引数 | D0.L |

キュー番号: 0 = 受信，1 = 送信。

## コメントのルール（3.2 節 p.23）

- 書いた人は最低限のコメントを書く。各ルーチンの先頭に入力・戻り値・使うレジスタを書く。
- レビュー担当は，誰が読んでも分かるようにコメントを追記し，**名前を書く**（最終試問で評価される）。

  ```
  	move.w	(%SP)+,%SR      | [レビュー: 山田] 退避した走行レベルを戻す
  ```

## git の使い方（最小限）

毎回この順番だけ守れば大丈夫。GitHub Desktop や VS Code のボタンでも同じことができる。

```sh
git pull                        # 1. 作業を始める前に最新を取ってくる
# 2. 自分の担当ファイルを編集する
git add os_queue.s              # 3. 変更したファイルを登録
git commit -m "INQ を実装"      # 4. 何をしたか一言書いて記録
git push                        # 5. GitHub に送る
```

- **自分の担当ファイル以外は編集しない**（他の人のファイルを直したいときは本人に伝える）。これで衝突（コンフリクト）はほぼ起きない。
- `os_queue.s` と `os_uart.s` は受信・送信の 2 人で共有するので，触る前に一声かける。
- `git push` が拒否されたら，もう一度 `git pull` してから `git push`。
- 困ったら何もせずに班の git に慣れている人を呼ぶ。
- 動くところまで進んだら `git tag step5` のように Step 名でタグを付けておくと，後で戻れる。

## 日程（説明会資料）

10/22 担当決め，10/23 Step1，10/27 Step2，10/28 Step3，10/29 Step4，11/4 Step5，11/6 Step6，11/10 Step7，11/11 Step8，11/12 Step9，11/13 Step10，11/17 試問準備・レポート，11/18・19 試問。

# ソフトウェア実験Ⅰ 簡易 OS（班リポジトリ）

68000 互換 CPU（MC68VZ328）ボード上で動く簡易 OS とエコーバックプログラムを班で開発するためのリポジトリ。
仕様はすべて「ソフトウェア実験I テキスト」に従う（ページ番号はテキストの印刷ページ）。

## メンバーと担当（表 3.1 p.22，5 人班）

| 担当 | 名前 | 主なファイル | レビュー担当 |
|---|---|---|---|
| 初期化 | 神井 | `os_init.s`, `os_interface.s`, `main_echo.s` | 松岡（タイマ） |
| 初期化 | 副田 | `os_init.s`, `os_interface.s` | 松岡（タイマ） |
| タイマ | 松岡 | `os_timer.s` | 神井・副田（初期化） |
| 受信 | 安森 | `os_queue.s`, `os_uart.s`（INTERGET, GETSTRING） | 田邉（送信） |
| 送信 | 田邉 | `os_queue.s`, `os_uart.s`（INTERPUT, PUTSTRING） | 安森（受信） |

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

## 環境の構築（最初の 1 回だけ）

git を初めて使う人も，上から順にそのまま打てば準備が終わる。`#` から右はコメントなので打たなくてよい。

### 事前にやること（ブラウザで）

1. GitHub のアカウントを作り，ユーザー名を班のリポジトリ管理者に伝える。
2. 招待メール（または https://github.com/notifications ）の **Accept invitation** を押す。clone は招待なしでもできるが，招待を受けないと push できない。
3. パスワードの代わりに使う **トークン** を作る。
   GitHub 右上のアイコン → Settings → Developer settings → Personal access tokens → **Tokens (classic)** → Generate new token (classic)。
   Note に「softexp1」，Expiration は実験が終わる日より後，チェックは **repo** だけ付けて Generate。
   表示された `ghp_...` の文字列をメモする（画面を閉じると二度と見られない。人に見せない）。

### 端末でやること（ここをまとめて打つ）

```sh
git --version                                   # 1. git が入っているか確認。バージョンが出れば OK

git config --global user.name  "Taro Kyushu"    # 2. 自分の名前（ローマ字）。コミットに記録される
git config --global user.email "you@example.com" #    GitHub に登録したメールアドレス
git config --global credential.helper "cache --timeout=36000"  # 3. トークンを 10 時間だけ覚えさせる（ディスクには保存しない）

cd ~                                            # 4. ホームに移動
git clone https://github.com/KamiiAoto/softexp1-os.git   # 5. リポジトリを手元にコピー（公開リポジトリなのでログイン不要）
cd softexp1-os                                  # 6. リポジトリの中に入る
ls                                              # 7. README.md や os_*.s が見えれば成功
git status                                      # 8. "On branch main" "up to date" と出れば OK

m68k-as -t 400 test_step1.s                     # 9. アセンブルできるか確認（test_step1.abs ができる）
```

- **手順 2（名前とメール）は必須。** git はコミットのたびに「誰が変更したか」としてこの 2 つを記録する。設定しないと `Please tell me who you are` と出てコミットできない。
  - メールを GitHub に登録したものにすると，コミットが自分のアカウントにひも付く（誰が書き，誰がレビューしたかが履歴で追える）。
  - このリポジトリは公開なので，名前とメールも公開される。大学のメールを出したくなければ，GitHub の Settings → Emails に出る `数字+ユーザー名@users.noreply.github.com` を使う。
  - `--global` は「この PC のこのアカウント全体」の設定。実験室の PC を複数人が同じアカウントで使うなら，`--global` を付けずに `cd softexp1-os` の後で `git config user.name ...` と打つ（このリポジトリだけの設定になり，他人の名前でコミットしてしまうのを防げる）。
- **手順 3（トークンを覚えさせる）は任意。** ないと push のたびにユーザー名とトークンを聞かれるだけで，動きはする。
  - `cache` はメモリに 10 時間（36000 秒）だけ覚え，ファイルには残さない。ログアウトか時間切れで消えるので共用 PC でも安全。
  - `store` にすると二度と聞かれなくなるが，トークンがファイルにそのまま残るので共用 PC では使わない。
- 手順 2・3 は PC ごとに 1 回だけ。手順 5 も 1 回だけで，次からは `cd ~/softexp1-os` → `git pull` から始める（下の「git の使い方」）。
- `git --version` で `command not found` と出たら git が入っていない。実験室の PC なら TA に聞く。自分の Mac なら `xcode-select --install`，Windows なら Git for Windows を入れる。
- 初めて `git push` したときにログインを求められる。
  - `Username`: GitHub のユーザー名
  - `Password`: 事前に作ったトークン（`ghp_...`）を貼り付け。何も表示されないが入力されている
- push で `Authentication failed` と出たら，Password にトークンではなく GitHub のパスワードを入れている（GitHub はパスワードを受け付けない）。
- push で `Permission denied` や `403` と出たら，招待を Accept していない。
- 実験室の PC は共用なので，トークンをファイルに書いて残さない。手順 3 の設定ならログアウトや時間切れで忘れる（次回の push でもう一度聞かれる）。

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

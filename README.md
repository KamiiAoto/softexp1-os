# ソフトウェア実験Ⅰ 簡易 OS（班リポジトリ）

MC68VZ328（68000 互換）ボードで動く簡易 OS を班で作るリポジトリ。
仕様は「ソフトウェア実験I テキスト」に従う（ページ番号は印刷ページ）。

**現状:** 簡易 OS は完成し，実機でエコーバックの動作確認まで済んでいる（Step 9）。今は各自の個人課題（Step 10）の段階。

| やりたいこと | 見るところ |
|---|---|
| 個人課題を始める | [1. 個人課題の進め方](#1-個人課題の進め方) |
| ユーザプログラムの書き方を知る | [2. ユーザプログラムの決まり](#2-ユーザプログラムの決まり) |
| アセンブル・実行・git のコマンド | [3. 毎回の作業](#3-毎回の作業) |
| 初めてこのリポジトリを使う | [5. 環境の構築](#5-環境の構築最初の-1-回だけ) |

---

## 1. 個人課題の進め方

**OS には手を入れず，ユーザプログラム（`MAIN`）だけを自分で書いて差し替える。**

OS は初期化が終わると `bra MAIN` でユーザプログラムに飛ぶ。
`main_echo.s` は OS と `user_echo.s`（`MAIN` を定義）を `.include` で並べているだけなので，`user_echo.s` を自分のファイルに替えれば，自分のプログラムが同じ OS の上で動く。

```sh
git pull                                    # 1. 最新を取ってくる
cp user_echo.s user_<名前>.s                # 2. ユーザプログラムのひな形
cp main_echo.s main_<名前>.s                # 3. 入口ファイル
                                            #    → .include "user_echo.s" を "user_<名前>.s" に書き換える
                                            #      （ほかの行と順番はそのまま）
                                            # 4. user_<名前>.s の MAIN 以下を書き換える
m68k-as -t 400 main_<名前>.s                # 5. アセンブル
m68k-term                                   # 6. 実機で実行（→ 3. 毎回の作業）
sh tools/bundle.sh main_<名前>.s <名前>.s   # 7. 提出用の 1 ファイル → dist/<名前>.s
m68k-as -t 400 dist/<名前>.s                #    1 ファイル版もアセンブルできるか確認
git add user_<名前>.s main_<名前>.s dist/<名前>.s
git commit -m "Step 10: ○○を作成"
git push                                    # 8. 自分のファイルだけ push
```

> `dist/simple_os.s` をコピーして `begin user_echo.s` 〜 `end user_echo.s` の部分を書き換えても動く。
> ただし OS が修正されたときに取り込めないので，上の方法をすすめる。

## 2. ユーザプログラムの決まり

1. **`MAIN` を必ず定義する。** 先頭の 2 行（ユーザモードへの切り替えとユーザスタックの設定）は `user_echo.s` のまま残す。
2. **入出力とタイマはシステムコール（`trap #0`）で行う。** UART・タイマのレジスタは直接触らない。
3. **OS と同じラベル名を使わない**（アセンブル時にエラーになる）。
   OS では `boot`, `INQ`, `OUTQ`, `PUTSTRING`, `GETSTRING`, `SET_TIMER`, `RESET_TIMER`, `CALL_RP`, `task_p`, `SYS_STK`, `top0`, `s1` などを使っている。迷ったら名前の頭文字を付ける。
4. **置き場所:** コード → `.section .text`，初期値ありのデータ → `.section .data`，バッファ・スタック → `.section .bss`。
5. **編集しないファイル:** `os_*.s`, `main_echo.s`, `user_echo.s`, `dist/simple_os.s`。OS の不具合は担当者（[4.2](#42-メンバーと担当)）に伝える。
6. **動作確認は実機で。** BSVC（エミュレータ）では UART とタイマが動かない。

### システムコール

`%D0` に番号（`os_defs.s` の `SYSCALL_NUM_*`），`%D1` 以降に引数を入れて `trap #0`。戻り値は `%D0`。

| 番号 | 機能 | 引数 | 戻り値 |
|---|---|---|---|
| 1 `GETSTRING` | 受信した文字を読む | `%D1` = 0, `%D2` = バッファ, `%D3` = 最大バイト数 | 読めたバイト数 |
| 2 `PUTSTRING` | 文字を送信する | `%D1` = 0, `%D2` = データ, `%D3` = バイト数 | 書けたバイト数 |
| 3 `RESET_TIMER` | タイマを止める | なし | なし |
| 4 `SET_TIMER` | タイマを設定する | `%D1.W` = 周期 t, `%D2` = 呼ぶルーチン | なし |

- **GETSTRING は入力を待たない。** 何も打たれていなければすぐ 0 が返る。待つならループで呼ぶ（`user_echo.s` の `LOOP`）。
- **SET_TIMER の t は 0.1 ms 単位。** 50000 で 5 秒。
- **タイマで呼ぶルーチン** は割り込みの中で呼ばれる。レジスタを `movem.l` で退避・復元し，`rts` で終わる（`user_echo.s` の `TT` と同じ形）。

## 3. 毎回の作業

### git

```sh
git pull                        # 作業の前に必ず
# 自分のファイルを編集する
git add <ファイル>
git commit -m "何をしたか一言"
git push
```

- 自分の担当ファイル以外は編集しない（直したいときは本人に伝える）。
- `push` が拒否されたら，`git pull` してからもう一度 `git push`。
- 動いたら `git tag step10` のようにタグを付けておくと，後で戻れる。
- 困ったら何もせず，班の git に慣れている人を呼ぶ。

### アセンブルと実行（付録 A）

**必ずリポジトリの直下で打つ。**（`cd test` してから打つと `.include` が `can't open` になる）

```sh
m68k-as -t 400 main_echo.s        # main_echo.abs, main_echo.LIS ができる
m68k-as -t 400 test/test_step5.s  # テストも直下で打つ（.abs は直下にできる）
m68k-term                         # 実機: C-\ c → xm main_echo.abs → c → 何かキーを押す
m68k-emu                          # エミュレータ（内蔵デバイスは動かない）
```

### 提出用の 1 ファイル化（付録 A.6.3.2）

`.include` を展開して `dist/` に 1 ファイルを作る。

```sh
sh tools/bundle.sh main_echo.s simple_os.s   # → dist/simple_os.s
m68k-as -t 400 dist/simple_os.s              # 元と同じようにアセンブルできるか確認
```

## 4. リファレンス

### 4.1 ファイル構成

| ファイル | 内容 |
|---|---|
| `os_defs.s` | 定数（レジスタのアドレス，システムコール番号，キュー番号） |
| `os_init.s` | `boot`（初期化）。0x400 番地から始まる |
| `os_interface.s` | 割り込みインタフェース（送受信・タイマ），システムコールインタフェース |
| `os_queue.s` | `QUEUE_INIT`, `INQ`, `OUTQ`（Step 0） |
| `os_uart.s` | `INTERPUT`, `PUTSTRING`, `INTERGET`, `GETSTRING`（Step 4〜6） |
| `os_timer.s` | `RESET_TIMER`, `SET_TIMER`, `CALL_RP`（Step 7） |
| `user_echo.s` | Step 9 のユーザプログラム（エコーバック） |
| `main_echo.s` | 班の成果物の入口（`.include` を並べるだけ） |
| `dist/simple_os.s` | `main_echo.s` を 1 ファイルにまとめた提出用 |
| `test/` | 各 Step のテスト（`test_*.s`）とテスト用の `os_init_step4.s` |
| `tools/bundle.sh` | 提出用の 1 ファイルを作るスクリプト |

- 入口ファイル（`main_*.s`, `test/test_*.s`）は最初に `os_defs.s` → `os_init.s` の順で `.include` する（`boot` を 0x400 番地に置くため）。
- `os_*.s` の中では `.include` を使わない。

### 4.2 メンバーと担当

表 3.1（p.22），5 人班。

| 担当 | 名前 | 主なファイル | レビュー |
|---|---|---|---|
| 初期化 | 神井 | `os_init.s`, `os_interface.s`, `main_echo.s` | 松岡 |
| 初期化 | 副田 | `os_init.s`, `os_interface.s` | 松岡 |
| タイマ | 松岡 | `os_timer.s` | 神井・副田 |
| 受信 | 安森 | `os_queue.s`, `os_uart.s`（INTERGET, GETSTRING） | 田邉 |
| 送信 | 田邉 | `os_queue.s`, `os_uart.s`（INTERPUT, PUTSTRING） | 安森 |

`os_queue.s` と `os_uart.s` は受信・送信の 2 人で共有しているので，触る前に一声かける。

### 4.3 OS 内部ルーチンの引数（テキストの仕様。変えない）

| ルーチン | 入力 | 戻り値 |
|---|---|---|
| `INQ` | `D0.L` = キュー番号, `D1.B` = データ | `D0.L` = 0 失敗 / 1 成功 |
| `OUTQ` | `D0.L` = キュー番号 | `D0.L` = 0 / 1, `D1.B` = データ |
| `INTERPUT` | `D1.L` = ch | なし |
| `INTERGET` | `D1.L` = ch, `D2.B` = データ | なし |
| `PUTSTRING` | `D1.L` = ch, `D2.L` = p, `D3.L` = size | `D0.L` = 書き込んだ数 |
| `GETSTRING` | `D1.L` = ch, `D2.L` = p, `D3.L` = size | `D0.L` = 読み出した数 |
| `RESET_TIMER` | なし | なし |
| `SET_TIMER` | `D1.W` = t, `D2.L` = p | なし |

キュー番号: 0 = 受信，1 = 送信。

### 4.4 コメントのルール（3.2 節 p.23）

- 書いた人: 各ルーチンの先頭に入力・戻り値・使うレジスタを書く。
- レビュー担当: 分かりやすくコメントを足し，**名前を書く**（最終試問で評価される）。

  ```
  	move.w	(%SP)+,%SR      | [レビュー: 山田] 退避した走行レベルを戻す
  ```

### 4.5 日程

| 日付 | 内容 |
|---|---|
| 10/22 | 担当決め |
| 10/23 〜 11/12 | Step 1 〜 9（10/23 S1，10/27 S2，10/28 S3，10/29 S4，11/4 S5，11/6 S6，11/10 S7，11/11 S8，11/12 S9） |
| 11/13 | Step 10（個人課題） |
| 11/17 | 試問準備・レポート |
| 11/18・19 | 試問 |

## 5. 環境の構築（最初の 1 回だけ）

### 5.1 ブラウザでやること

1. GitHub のアカウントを作り，ユーザー名をリポジトリ管理者に伝える。
2. 招待メール（または <https://github.com/notifications>）で **Accept invitation** を押す。押さないと push できない。
3. パスワードの代わりに使う **トークン** を作る。
   右上のアイコン → Settings → Developer settings → Personal access tokens → **Tokens (classic)** → Generate new token (classic)。
   Note は「softexp1」，Expiration は実験の終了日より後，チェックは **repo** だけ。
   表示される `ghp_...` をメモする（二度と表示されない。人に見せない）。

### 5.2 端末でやること

```sh
git --version                                    # バージョンが出れば OK
git config --global user.name  "Taro Kyushu"     # 名前（ローマ字）【必須】
git config --global user.email "you@example.com" # GitHub に登録したメール【必須】
git config --global credential.helper "cache --timeout=36000"  # トークンを 10 時間覚える【任意】

cd ~
git clone https://github.com/KamiiAoto/softexp1-os.git
cd softexp1-os
git status                                       # "On branch main" と出れば OK
m68k-as -t 400 test/test_step1.s                 # アセンブルできるか確認
```

次からは `cd ~/softexp1-os` → `git pull` から始める。

初めて `git push` したときは，`Username` に GitHub のユーザー名，`Password` にトークン（`ghp_...`）を入れる（入力しても何も表示されない）。

<details>
<summary>設定の補足（共用 PC・メールアドレス・トークンの保存）</summary>

- 名前とメールはコミットに記録される。設定しないと `Please tell me who you are` と出てコミットできない。
- リポジトリは公開なので，メールも公開される。隠したいときは GitHub の Settings → Emails にある `数字+ユーザー名@users.noreply.github.com` を使う。
- 実験室の PC を複数人が同じアカウントで使うときは，`--global` を付けずに `softexp1-os` の中で `git config user.name ...` と打つ（他人の名前でコミットするのを防ぐ）。
- `cache` はトークンをメモリに 10 時間だけ覚え，ファイルには残さないので共用 PC でも安全。`store` はファイルに残るので共用 PC では使わない。

</details>

### 5.3 困ったとき

| 症状 | 原因と対処 |
|---|---|
| `git: command not found` | git が入っていない。実験室なら TA に聞く。Mac は `xcode-select --install`，Windows は Git for Windows |
| push で `Authentication failed` | Password に GitHub のパスワードを入れている。トークンを入れる |
| push で `Permission denied` / `403` | 招待を Accept していない |
| push が拒否される（rejected） | `git pull` してからもう一度 `git push` |
| `.include` で `can't open` | リポジトリの直下で打っていない |

### 5.4 自分の PC でアセンブルする（m68k-bsvc-docker）

自分の PC には `m68k-as` がないので，**[m68k-bsvc-docker](https://github.com/KamiiAoto/m68k-bsvc-docker)** を使う。
m68k-as と BSVC（68000 シミュレータ）を Docker にまとめたもので，Apple Silicon の Mac でも動く。
Docker Desktop が必要。初回の起動はビルドに 20 分ほどかかる。

```sh
cd ~                                            # softexp1-os と同じ場所に置く
git clone https://github.com/KamiiAoto/m68k-bsvc-docker.git
cd m68k-bsvc-docker
echo "WORKSPACE=../softexp1-os" > .env          # softexp1-os をコンテナの /root/work に見せる
docker compose up -d                            # 起動（終了は docker compose down）

docker compose exec m68k-bsvc bash              # コンテナに入る
cd /root/work                                   # = softexp1-os の直下
m68k-as -t 400 main_echo.s                      # 実験室と同じコマンドが使える
```

- `.abs` などは自分の PC の softexp1-os にもできる（`.gitignore` の対象なので push はされない）。
- BSVC は <http://localhost:6080/vnc.html> で Connect → File → Load Program で `.abs` を読み込み，PC を `0x400` にして実行する。
- BSVC では UART・タイマが動かない。確認できるのはアセンブルとキューなどのロジックだけ。
- 詳しくは m68k-bsvc-docker の README を見る。

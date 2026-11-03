# 安全装置で防げる範囲と、運用上の約束にとどまる範囲

この設定の安全装置は **Claude Code の中でだけ** 働き、しかも完全ではありません。
「設定で止まること」と「約束しているだけのこと」を分けて書きます。
一番確実なのは GitHub 側の保護（4 章）で、これは AI ツールの種類に関係なく効きます。

## 1. 層ごとの効き方

| 層 | 仕組み | 効く範囲 | 効かない範囲 |
|---|---|---|---|
| A. 権限ルール | `.claude/settings.json` の allow / ask / deny | Claude Code のツール呼び出し。Bash はコマンドの **先頭一致**、Read はパス、MCP はツール名で判定 | 先頭が違う書き方（`cd x && rm -rf y`、`bash script.sh`）。Read の deny は Read ツールだけで、Bash の `cat` は対象外 |
| B. フック | `.claude/hooks/guard-bash.sh`（Bash ツールの実行前） | コマンド文字列に、危険な操作の典型的な書き方が含まれる場合 | 下の 3 章を参照。正規表現なので、すり抜けも誤検知もある |
| C. ツールの付与 | `.claude/agents/*.md` の `tools:` | reviewer / verifier には Edit / Write を渡していない | **Bash を持つので、ファイルへの書き込みは技術的に可能**（`echo > file`、`sed -i`、`git commit`）。「読み取り専用」は約束であって強制ではない |
| D. 事後の確認 | CLAUDE.md の手順 6（統括役が `git status` と HEAD を確認） | reviewer / verifier が変更を残した場合に **検出** できる | 防止はできない。作業ツリーの外（`/tmp`、他のディレクトリ）への書き込みは見えない |
| E. GitHub の保護 | ブランチ保護・ruleset・必須チェック | AI ツールの種類やローカル設定に関係なく、main への push・マージを止める | **現在は未設定**（4 章） |

## 2. 項目別：設定で止まるか、約束だけか

| 禁止事項 | 設定で止まる | 約束だけ（すり抜け得る） |
|---|---|---|
| `rm -rf` | A（先頭一致）、B（文字列一致） | 変数・スクリプト経由、`node -e` などからの削除 |
| 強制 push・main への push | A・B（典型的な書き方） | 引数なしの `git push`（今のブランチが main の場合）。**E を設定すれば確実に止まる** |
| PR のマージ | A（GitHub MCP の merge / 自動マージを deny）、B（`gh pr merge`） | 他の手段からの API 呼び出し。**E を設定すれば確実に止まる** |
| GitHub の API での直接書き込み | A（MCP の push_files / create_or_update_file / delete_file を deny） | `curl` で直接 API を叩く場合 |
| `.env` や秘密情報の表示 | A（Read ツール）、B（`.env` を含むコマンド、`printenv` / `env`） | 別名のファイル、スクリプト経由、`export -p` や `set` |
| reviewer / verifier の書き込み | C（Edit / Write なし） | Bash 経由の書き込み → D で検出 |
| テストの削除・弱体化、`check.config` の変更 | なし | reviewer の確認観点、および PR での人の確認 |
| 依存の追加 | A（`npm install` などは ask） | 別のパッケージマネージャー、`package.json` の直接編集 |
| 課金 API・DB のスキーマ変更 | なし（B は DROP / TRUNCATE だけ） | 約束のみ。本番の認証情報を環境に置かないことが最も確実 |

## 3. フック（guard-bash.sh）の限界

`tests/guard-bash.test.sh` に、止めるケースと **止められないケース** の両方をテストとして記録しています。
止められないことを確認している例:

- 引数なしの `git push`（今どのブランチにいるかは判別できない）
- 変数経由の削除（`R=rm; $R -rf build`）
- スクリプトファイルの中身（`bash cleanup.sh`）
- 別言語からの単発の削除（`node -e '...unlinkSync...'`）
- Bash 経由の書き込み（`echo x > src/a.js`）
- 難読化（base64 で隠したコマンド）

誤検知もあります。「rm -rf」などの文字列を含むだけで止まります（コミットメッセージや echo の中身でも）。

## 4. GitHub 側の保護（現状と提案）

### 現状（2026-11-03 に読み取りで確認）
- リポジトリは **公開（public）**
- `main` はブランチ保護なし（`protected: false`）。ruleset は 0 件
- CI（`.github/workflows`）はなし。必須チェックもなし
- PR #1 の作成者も、マージした人も同じアカウント（`sketch-consulting`）

→ 今は、Claude Code 以外の手段（他の AI ツール、手作業、API）からなら、main への直接 push もマージも止まりません。

### 提案（設定は人が行う。このリポジトリでは変更していない）

**① ruleset（Settings → Rules → Rulesets → New branch ruleset）**
- 対象: Default branch（`main`）。Enforcement status: Active
- 有効にするルール:
  - Restrict deletions（削除の禁止）
  - Block force pushes（強制 push の禁止）
  - Require a pull request before merging（PR を経由しないと main に入らない）
    - Required approvals: **0 を推奨**。理由: AI が作る PR も同じアカウント名義なので、1 以上にすると自分で承認できず、マージできなくなる。人の確認は、マージボタンを押す行為で担保する
  - Require status checks to pass（②の CI を入れた後で `check` を追加）
- Bypass list: 空のまま（管理者も例外にしない）。緊急時は一時的に無効化する

**② CI（必須チェック）の案**
下を `.github/workflows/check.yml` として追加します。ただし今は `scripts/check.config` が未設定なので、
**入れた直後から CI は失敗（終了コード 2）になります**。これは意図どおりで、設定が済むまでマージできない状態になります。
先にプロジェクトを決めて `check.config` を埋めてから入れるのが現実的です。

```yaml
name: check
on:
  pull_request:
  push:
    branches: [main]
permissions:
  contents: read
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: 安全装置の自己テスト
        run: scripts/selftest.sh
      - name: 品質チェック（必須項目が未設定なら失敗）
        run: scripts/check.sh
```

**③ その他**
- 公開リポジトリのままでよいか判断する。顧客のコードや社内情報を入れるなら、非公開にする
- Settings → Actions → General → Workflow permissions は「Read repository contents」のままにする

## 5. 自己テスト

```
scripts/selftest.sh   # settings.json の形式、check.sh の判定、フックの止める／止められないケース
```

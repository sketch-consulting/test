# 安全装置で防げる範囲と、運用上の約束にとどまる範囲

この設定の安全装置は **Claude Code の中でだけ** 働き、しかも完全ではありません。
「設定で止まること」と「約束しているだけのこと」を分けて書きます。
GitHub 側の保護（4 章）は AI ツールの種類に関係なく効きますが、守れるのは「main への直接 push」「強制 push」「CI が通らない PR のマージ」までです。
**AI と人が同じ GitHub アカウントを使っている間は、「人だけがマージできる」ことは GitHub でも強制できません**（4 章）。

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
| 強制 push・main への push | A・B（典型的な書き方）。**E を設定すれば、誰が操作しても止まる** | E がない間は、引数なしの `git push`（今のブランチが main の場合）など |
| PR のマージ（AI によるもの） | A（GitHub MCP の merge / 自動マージを deny）、B（`gh pr merge`） | 他の手段からの API 呼び出し。**E を設定しても、同じアカウントなら AI のマージは止まらない**（4 章）。運用上の約束 |
| CI が通らない PR のマージ | E（必須チェックを設定した場合。誰が操作しても止まる） | E がない間は止まらない |
| GitHub の API での直接書き込み | A（MCP の push_files / create_or_update_file / delete_file を deny） | `curl` で直接 API を叩く場合 |
| `.env` や秘密情報の表示 | A（Read ツール）、B（`.env` を含むコマンド、`printenv` / `env`） | 別名のファイル、スクリプト経由、`export -p` や `set` |
| reviewer / verifier の書き込み | C（Edit / Write なし） | Bash 経由の書き込み → D で検出 |
| テストの削除・弱体化、`check.config` の変更 | なし | reviewer の確認観点、および PR での人の確認 |
| 品質チェックでの失敗の握りつぶし | check.sh（`bash -euo pipefail` で実行。`a \| b`、`a; b`、`a && b` のどこで失敗しても失敗。`\|\|`・`set +e`・`trap` を含む設定は不正として exit 2） | 呼び出し先のスクリプトの中身（例: `npm test` の中身に `\|\| true` がある）、`if` や `!` の中での失敗。reviewer が設定と呼び出し先を確認する |
| 依存の追加 | A（`npm install` などは ask） | 別のパッケージマネージャー、`package.json` の直接編集 |
| 課金 API・DB のスキーマ変更 | なし（B は DROP / TRUNCATE だけ） | 約束のみ。本番の認証情報を環境に置かないことが最も確実 |

## 3. フック（guard-bash.sh）の限界

`tests/guard-bash.test.sh` に、止めるケースと **止められないケース** の両方をテストとして記録しています。
コマンド文字列は JSON から取り出し（jq → python3 → どちらもなければ JSON 全体）、引用符とバックスラッシュを取り除いてから判定します。
そのため `cat ".env"`、`cat .env .env.example`（複数パス）、`git push origin "HEAD:main"` も止まります（回帰テストあり）。
それでも、止められないことを確認している例:

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

### 何が保証され、何が保証されないか（同一アカウントの場合）
現状、AI（Claude）が作る PR も、あなたが操作する PR も、同じ `sketch-consulting` アカウントの名義です。
GitHub から見ると両者を区別できないため、ruleset を設定しても次のようになります。

| 守りたいこと | ruleset で強制できるか |
|---|---|
| main への直接 push・強制 push・ブランチ削除を止める | ✅ できる（誰が操作しても止まる） |
| CI（必須チェック）が通らない PR をマージさせない | ✅ できる（②の CI を入れた場合） |
| 人がレビューしてからマージする | ❌ できない。承認数 1 以上にすると、同じアカウントでは自分の PR を承認できず、人もマージできなくなる。承認数 0 では、AI もマージできてしまう |
| AI はマージせず、人だけがマージする | ❌ できない。Claude Code 側の deny（GitHub MCP のマージ系、`gh pr merge`）と、CLAUDE.md の約束にとどまる |

### 人だけがマージできるようにするには（権限分離の選択肢）
- **選択肢 1: AI 用に別の GitHub アカウントを使う。** AI はそのアカウントの資格情報だけで push・PR 作成を行い、あなたは自分のアカウントで承認する。
  ruleset で「承認 1 以上」と「最後の push をした人以外の承認が必要」（Require approval of the most recent reviewable push）を有効にすれば、
  AI のアカウントだけでは main に入れられなくなる。
  - 注意: Claude のクラウドセッションの GitHub 連携は、現在あなたのアカウント名義で動いている。別アカウントにできるかは連携方法次第で、ここでは確認していない。
  - 注意: 承認後に「マージボタンを押す人」まで絞るには、Organization 所有のリポジトリでブランチ保護の push 制限を使う必要がある（個人アカウント所有のリポジトリでは使えない）。
- **選択肢 2: 同じアカウントのまま運用する。** ruleset は上の ✅ の範囲だけを守り、「人だけがマージする」は運用上の約束として残す。
  Claude Code 側の deny とフックで、よくある経路は止まるが、すり抜けは残る（2 章・3 章）。

### 提案（設定は人が行う。このリポジトリでは変更していない）

**① ruleset（Settings → Rules → Rulesets → New branch ruleset）**
- 対象: Default branch（`main`）。Enforcement status: Active
- 有効にするルール:
  - Restrict deletions（削除の禁止）
  - Block force pushes（強制 push の禁止）
  - Require a pull request before merging（PR を経由しないと main に入らない）
    - Required approvals: 同じアカウントで運用する間は **0**（1 以上にするとマージできなくなる）。
      このとき「人が確認してからマージする」は GitHub では強制されず、運用上の約束になる（上の表）。
      選択肢 1 で AI 用アカウントを分けた場合は **1 以上** にし、「最後の push をした人以外の承認」も有効にする
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

## 5. 品質チェックの「すべて対象外（NA）」について（提案。未実装）

現行の check.sh は、lint・型検査・テストの 3 つすべてを `NA:<理由>` にすると成功（exit 0）になります（`tests/check.test.sh` に現行仕様として記録）。
「何も実行していないのに成功」になるため、次のどれかに変えることを提案します。

| 案 | 内容 | 利点 | 欠点 |
|---|---|---|---|
| A. 現行のまま | 3 つとも理由付きで NA にできる | 文書だけのリポジトリなどにも使える | 何も実行せずに成功できる。NA の妥当性は人の確認頼み |
| B. 全部 NA は未設定扱い | 少なくとも 1 つは実際に実行して成功する必要がある（全部 NA なら exit 2） | 「何も実行せずに成功」を防げる | lint だけ実行してテストは NA、は許してしまう |
| **C. テストは NA 不可（推奨）** | lint・型検査は理由付きで NA 可。テストは必ず実行する（NA なら exit 2） | 検証役が「修正前に失敗し、修正後に通る」を確かめる前提が崩れない。全部 NA も自動的に不可 | テストのないリポジトリ（文書だけなど）では、この仕組みをそのまま使えない |

推奨は C です。このチームの最初の用途は回帰バグの修正で、テストが合否の根拠になるためです。
どれにするかは判断をお願いします。決まれば check.sh と回帰テストを変更します。

## 6. 自己テスト

```
scripts/selftest.sh   # settings.json の形式、check.sh の判定、フックの止める／止められないケース、作業場所の作り分け
```

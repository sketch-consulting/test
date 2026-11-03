# 外部から取り込んだスキル

中身を確認したうえで、特定のコミットに固定してコピーしています。更新するときは差分を読んでから取り込み、この表を書き換えてください。

| スキル | 取得元 | コミット | ライセンス | このリポジトリでの変更 |
|---|---|---|---|---|
| grilling | github.com/mattpocock/skills `skills/productivity/grilling` | 4ae2317ddb22b046e26455e4f9c9b3aaaf62212d | MIT | なし |
| grill-me | github.com/mattpocock/skills `skills/productivity/grill-me` | 4ae2317ddb22b046e26455e4f9c9b3aaaf62212d | MIT | なし（`grilling` を呼ぶだけ。`/grill-me` で手動起動） |
| systematic-debugging | github.com/obra/superpowers `skills/systematic-debugging` | 2ce8aa15d05bd57213e6f746f953aafb7ded7a8b | MIT | 未取り込みの superpowers スキル 2 件への参照を、このリポジトリの手順（implementer の手順 3、`scripts/check.sh`）に置換。作成記録とテスト用シナリオ（CREATION-LOG.md, test-*.md）は除外 |

取り込まなかったもの: 各リポジトリの `agents/openai.yaml`（Claude Code では使われない）

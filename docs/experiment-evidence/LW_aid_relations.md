# 主観的援助期待の有限比較

2026-10-04。[契約](../experiment-contracts/LW_aid_relations.md)。
3条件×独立2 Episode。EnergyWorldの幾何・身体・食料消費・救援声を使用。

| 初回条件 | AのBへの期待 | Cへの期待 | 次に期待する相手 | 後日Bに救助された後 |
| --- | ---: | ---: | --- | ---: |
| Bが給食 | 2/3 | 1/2 | B | 3/4 |
| Bが聞いたがrest | 1/3 | 1/2 | C | 1/2 |
| Bが受信不能 | 1/3 | 1/2 | C | 1/2 |

後二者のA側evidenceは完全一致。B側受信記録は異なる。
Aの更新は「意図的に見捨てられた」という事実認定を含まない。
B→Aは全条件0.5のまま。後日救助でも旧無応答を削除せず、新Episodeを追加する。
実給食が複数回でも関係支持は1 Episode単位。

専用4＋声救助/エネルギー接続/身体の計23テストPASS。
未観測相手拒否、期限、別相手/期限外給食の非混入、再送・再評価非増殖を確認。
全体suite、Luanti、通常探索、長期Sleep統合は未実施。

`python -m integrations.lightweight.aid_relation_experiment`
保存: `tests/fixtures/aid_relations.json`。実験者条件、Bの受信と実作用、Aのevidenceを分離保存。

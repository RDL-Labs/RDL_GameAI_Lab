# 要求・譲渡・拒否・警告の一往復

2026-10-04。[契約](../experiment-contracts/LW_minimal_communication.md)。
軽量Worldの5独立条件、各3操作。Aのreserve=50、Bの食料=1を初期設定。

| 条件 | 実行列 | 結果 |
| --- | --- | --- |
| 譲渡可能 | request → give → eat | Aのreserve 50→70、食料1消費 |
| 拒否 | request → refuse → wait | Aに明示拒否が届く |
| 受信不能 | request → wait → wait | Aには応答なし |
| 警告に従う | reach → warn → withdraw | 食料はBが保持 |
| 警告後も続行 | reach → warn → reach | 食料はBが保持 |

全条件で残存inventory合計＋消費数=1。聞こえない原因は実験者の設定で、
Aへ「無視された」という事実を渡していない。
固定初期能力と傾向の比較であり、性格の学習や自律交渉成立は主張しない。

専用5＋援助関係/救助/エネルギー接続/身体の計28テストPASS。
失効、接触範囲、要求者結合、一要求一応答、再送、保持境界、本人/他者観測分離を検査。
全体suite・実Luanti・通常探索・長期運転は未実施。

再実行: `python -m integrations.lightweight.minimal_communication`
保存: `tests/fixtures/minimal_communication.json`。

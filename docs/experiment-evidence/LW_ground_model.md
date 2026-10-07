# LW統合版：暫定地面M_Bと探索の接続

2026-10-07、基準cb8bd8a。[契約](../experiment-contracts/LW_ground_model.md)。
前回の形成30日Worldを継承、未学習3個体、接続なし/あり各30日。
地面形成・回復・認識は両条件有効。変更はground_continuity_enabledのみ。

| 条件 | 採取 | 食事 | 道候補がある判断 | 道候補選択 | 最終実行 |
|---|---:|---:|---:|---:|---:|
| disabled | 91 | 91 | 0 | 0 | 0 |
| enabled | 92 | 91 | 9 | 9 | 1 |

選択9件のうち6件はbody_phase_boundaryによるwait、2件は食事/要求が優先。
残る1件はnpc_b、後半1046.25秒、food/ground_72によるmove0.5。
実resultは1047.25秒、moved/forward0.5。道を常に追わせてはいない。

暫定モデル累計382（再形成を含みdistinctな道の数ではない）、最大同時active4。
対応linkを持つモデルの延べ判断参照3,091、観測条件変化121。
保存された4,608判断の全モデルが原観測・身体resultからの再計算と一致。
command kind/amountは322判断で異なる。後続の相互作用を含む差であり、
322件の直接的な道追従があったという意味ではない。

実運転で道候補のH加算は0件。blocked後H=1で別候補へ切り替わることは
合成試験で確認。実運転で長い道を追い続けたり、停滞をHで脱出した結果ではない。
接続なしの採取/食事/最終身体状態は前回のinherited条件と再現一致。
両条件とも全員の最終reserveは正。食料保存・重複/重なる身体作用なし・完走PASS。

関連47テストPASS（地面M_B10件を含む）。実測移動/旋回、遮蔽と草への回復、
曖昧対応、個体束縛、有限履歴、H切替、身体/危険/夜間gate、再送を確認。
全体suiteおよびLuantiは未実行。これは軽量Worldの結果。

採取+1は1seedの有限差。拠点近くに資源がある配置のため、未知の遠方資源へ
道が導く効果・一般効率改善・道の意味理解は未確認。
短期の観測まとまり→既存探索候補→実移動という接続の成立として扱う。
長期の道M_B・分岐統合・canonical採用・Sleepによる道モデル整理は未実装。

[集計と実行出典](LW_ground_model.json)。
実行 `python -m integrations.lightweight.ground_model_campaign`。
再監査 `python -m integrations.lightweight.audit_ground_model`。
生ログ `outputs/ground_model/{disabled,enabled}.jsonl`。

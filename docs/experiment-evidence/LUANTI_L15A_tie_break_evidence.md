# L15A — ξ_tie単独実験 Evidence

2026-09-28。基準 `main@122e4f4`。[契約](../experiment-contracts/LUANTI_L15A_tie_break_contract.md)。
**有限な摂動・受付・身体接続は検証できたが、今回の主比較で移動改善は確認できなかった。**
草地では7判断へ適用しても元の選択と一致し、森林では適格な拮抗が0件だった。
強い差や適用条件外の停滞を解決するために、幅・係数・seedを変更していない。

## 実装範囲

`runtime/terrain_tie_break.py` は探索接続v1から独立したopt-in入口。
現在観測の適格な近同点だけへ±0.05以内の別寄与を加える。
候補全体の各成分差も0.10以内に限定し、成分の大きな相殺を弱い差として扱わない。
左右傾向neutral、方向維持disabled。5方向のうち正面も有効な拮抗なら選択対象となる。
観測値、摂動、最終値、seed順位を分離し、未適用nullと計算された0も区別する。

局面は最大3判断・750ms、取得時刻と実身体結果で検査する。
状態は受理済みdecisionから導出し、再送や拒否で番号・使用数を増やさない。
今回の実Worldでは適格局面はいずれも1判断で、次の候補集合・成分・移動結果で閉じた。
**3判断の保持、時間/回数上限、period境界、欠測による失効の正例はPython合成試験**である。
長期保持・プロセス再起動をまたぐ一回実行保証ではない。

## 事前固定した5run

3個体、各地点12単位、各2period（32秒）、master_seed=20260928。
A/B/Cのsteady/curious/restlessは固定。草地は近傍2資源、自然林は8資源。
run_idもseed材料に含み、全runのID・seed・元snapshotハッシュ・実行ソースハッシュを保存した。

| 条件 | run_id | 適用判断数 | 元のactionとの差 | 採取数 |
| --- | --- | ---: | ---: | ---: |
| 草地 disabled | l14b-353446c2e63d4225 | 0（適格7） | 0 | 0 |
| 草地 frozen | l14b-646fec4000834321 | 7 | 0 | 0 |
| 自然林 disabled | l14b-d9948578bf3d41ae | 0（適格0） | 0 | 0 |
| 自然林 frozen | l14b-c4c1a9a15376464d | 0 | 0 | 0 |
| 草地 frozen＋故障注入 | l14b-bb425deaf69b4e35 | 9 | 0 | 12 |

全5runを順序も含め事前宣言して実行し、追加seed探索は行っていない。
保存: `tests/fixtures/luanti_l15a_tie_break_replay.json.gz`（2,624,780 bytes）。
SHA-256: `0c487a84895218aa7690ad666d1779326de9aca23af445fdc68325ab4c95e277`。
全1920観測/command/result、15個体run、各個体128判断。
全HTTP wireからのstate再生、個体混線・二重作用拒否、sensor19アサーション/run、
ground5ray/obstacle8rayと実身体readback・資源在庫の独立監査を通した。
原snapshotのbyte hashと内容、実行ソースhashはarchive時に照合した。

## 旋回と停滞を分けた結果

以下は主比較のみ。逆旋回と連続turnは、既存と同じFood locomotion操作を対象とする。
並進間隔とセル滞在は全行動を対象とするWorld監査指標で、個体入力ではない。

| 地形 / 個体 | 逆旋回対 disabled→frozen | 最大連続turn | 最大並進間隔 秒 disabled→frozen | 最大2ノードセル滞在 秒 disabled→frozen |
| --- | ---: | ---: | ---: | ---: |
| 草地 A | 68→68 | 48→48 | 12.291→12.275 | 12.798→12.788 |
| 草地 B | 62→62 | 43→43 | 11.499→11.524 | 11.727→11.750 |
| 草地 C | 46→46 | 24→24 | 6.508→6.477 | 7.270→7.249 |
| 自然林 A | 23→23 | 24→24 | 10.464→10.463 | 10.464→10.463 |
| 自然林 B | 23→23 | 24→24 | 7.254→7.242 | 7.749→7.755 |
| 自然林 C | 20→20 | 21→21 | 9.487→9.502 | 11.254→11.246 |

主比較の各対応個体では、実行種別の数・移動距離・終点・訪問セル数も一致した。
独立runのHTTP/World実行時刻は完全には同じでなく、小さな時間差を改善とは扱わない。
最大並進間隔は実移動readback間（run始端/終端を含む）の最大時間。
セル滞在は水平2ノード四方のセルが変わるまでの時間で、32秒の有限World区間で打ち切る。
その場の採取もあり得るため、並進なしを「成果なし」「無駄」と同一視しない。

草地frozenの内訳はBが4適用（2旋回・2移動）、Cが3適用（1旋回・2移動）。
摂動後の各実選択は、**その同じ観測**におけるdisabled評価と一致した。
exact tieの左右選択やseedによる分岐は合成入力で検証済みだが、今回の自然Worldでの選択分岐の実証ではない。
この適用範囲のξ_tieだけで、既存の渦状停滞を解消できたとは言わない。

## 応答消失・遅延の別run

Runtimeが受理した適格decisionの応答をLuanti callbackで破棄し、同一観測を再送した。
元応答と再送応答のcommandは一致、`new_frames = 1 → 0`、そのoperationの実移動は1回。
seedは受理済みdecisionの同じ値で、同観測再送はepisodeを開始し直さない。
古いcallbackの再注入、個体混線、二重consumeの拒否も通った。
実ネットワーク切断ではなく、既存mailboxへの有限な故障注入である。

このrunではAが12個を採取し、既存の採取学習M_Bを採用後、予測の不成立でinvalidatedとなった。
全wire再生でも同じ学習状態となる。B/Cの摂動9適用にも元actionとの差は0。
**故障注入なしの主比較とは条件が違うため、採取12をξ_tieの効率改善と帰属させない。**
新しい移動学習やM_B権限は追加していない。

## 検証

専用 **25テストPASS**（22局所試験＋3実記録検査）、3.920秒。
exact/near tie、0値、候補除外、欠測、強い差、成分相殺、幅境界、最終値の同点、
seed出典と個体分離、入力/出力分離、局面保持・回数・期限・period・並進・優先処理での失効、
拒否時のatomic保持、同一観測8並列再送、設定凍結、既存採取・学習・variationの非介入を検査した。
disabledで既存実Luanti記録のcommand・learning・M_Bが同一になることも確認した。

全体回帰 **932件実行 = 881 PASS + 51 intentional skip**、331.776秒、exit code 0。
既存steering/lateral・L14B学習・観測/受付経路を含む。今回の新規実Luanti実行は上記5runであり、
全体テスト内の既存保存記録の再生を新規World実行として数えない。
実行ログ: `integrations/luanti/output/l15a_tie_tests.log` / `l15a_tie_full_tests.log`（Git管理外）。

```powershell
python -m unittest discover -s tests -p test_terrain_tie_break.py -v
python -m integrations.luanti.tests.run_terrain_tie_break --output integrations/luanti/output/l15a_tie_break_matrix.json
python -m unittest discover -s tests -v
```

個別起動は `run_multi_resource.run(..., tie_break="frozen")`、
または対応Runtimeと `test-learned-exploration-day.ps1 -MultiResources -TieBreakMode frozen`。
disabledは同じ診断を付けるv1対照。offでは既存mode。steering/lateral同時指定は拒否する。

今回でξ_tie単独を区切る。反復残存・減衰、停滞からの停止/再観測、興味・目的変更、
三者の合成は別契約とし、まだ実装していない。固定thinking delayや周期変更もない。

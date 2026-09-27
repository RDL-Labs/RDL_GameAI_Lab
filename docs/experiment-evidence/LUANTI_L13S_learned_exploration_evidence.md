# Luanti L13S — 日末Sleep・経路検査・M_B探索の実行記録

状態: FINITE ACCEPTANCE PASS。2026-09-27。
基準HEAD `8f8e30d` + L13S working tree。Core `86a0d4f3` / SPEC v2.5。
[契約](../experiment-contracts/LUANTI_L13S_learned_exploration_contract.md)、
[損失なし再生記録](../../tests/fixtures/luanti_l13s_replay.json.gz)。

## 今回成立したこと

色追従を与えない初期試行から実Food発見を得て、その日までの経験経路を日末に固定した。
別の日にharnessが検査目的で同じ経験経路を試し、観測・実測・終点のFoodを再確認した。
独立検査後の既存T1-A/B/C・cutoverを経たM_Bが、さらに次の日の実選択を変えた。
全系列を初回発見で止めず、別日3回発見で終了した。上限は30日。

Luanti 5.17.0 Windows / LuaJIT。昼間固定・直線の色帯と山3か所・既存16秒のWorld予算。
master seedは実行前固定の`20260927`。成功seedの検索、途中のFood救済、失敗日の削除は行っていない。
色帯の外も歩ける。World座標・Foodへの経路・山の恒久IDはRuntimeへ渡していない。

## 主系列（20実World日・1,280取得）

| 条件 | 第1発見日 | 第2発見日 | 第3発見日・終了 | M_B採用 | pickup |
| --- | --- | --- | --- | --- | --- |
| record: 記録保持のみ | 3 | 7 | 8 | なし | 0 |
| inspect: Sleep・経路Probe・検査・inactive artifact | 3 | 4（検査Probe） | 7 | なし | 0 |
| adopt: 同処理＋cutover | 3 | 4（検査Probe） | 5（active M_B） | 4日目末 | 0 |

一日最大1発見。各日64packet/遠景frame、全日time_limitで正常終了した。
発見した後の連続Food観測を追加の発見へ数えず、3回目の日の処理終了後に新しい日は起動していない。
**今回はFood発見の実験であり、取得・摂食・生存まで成功したとはしない。新系列の実pickupは0件。**

採用側で残った経路は、初回発見までの21回移動＋2回回転、計23操作。
13歩前進→左90度→5歩→右90度→3歩で、Foodが局所観測へ入った。
設計者がこの列を与えたのではなく、3日目の抽選と実測結果から保存された。
毎段の地表/遠景の観測条件と身体結果を照合し、4・5日目も23操作で再観測した。
道の全体理解・最短経路・一般的な「青い帯は餌へ続く」という規則ではない。

採用側の当日発見時刻は3日目5.755120秒、4日目5.775317秒、5日目5.760630秒。
経路そのものを短縮したのではなく、既に発見した経路を次の試行で選べるようになった。
第3発見までの累積World時間はrecord115.520188秒、inspect104.763659秒、adopt69.760630秒。
これらはこのseed・配置・予算での結果で、一般的な改善率ではない。

## 完全に同じ過去記録からの採用対照

主系列のinspect/adoptは別runなので、取得時計・run IDは異なる。
その比較だけでは完全同一Experienceを主張しないため、追加対照を行った。

adoptの1〜4日目の**同じ受理済みHTTP往復・Experience・候補・検査結果**を再生し、
同じinactive artifactまで再構築して、cutoverだけを無効にした枝を作った。
共有した4日は再生であり、新しい4回のWorld経験には数えない。
その枝の5〜7日目だけを、新しい実Luanti Worldとして実行した（追加3run・192取得）。

| 5日目 | active M_B | 同じ履歴・cutoverなし |
| --- | --- | --- |
| 現在Worldの初期条件・抽選列 | 共通 | 共通 |
| 初手 | move 1 | turn +90 |
| 選択根拠 | 採用済み経験経路の予測 | unknownの有限抽選 |
| 当日の発見 | あり、23操作後 | なし |
| 第3発見 | 5日目 | 7日目 |

さらに採用側の**同一初期packet**を親モデルへ渡す副作用なしの対照でも、前進/右回転の差を確認した。
この局所対照は実World分岐とは別。分岐後はそれぞれの実結果を保存し、以後の経験まで同一とは主張しない。
比較記録は同梱JSONの`shared_history_control.comparison`。

## Sleep・独立検査・T1の範囲

本版は「仮の経験経路1形成日＋別の1検査日」。旧計画の3形成日＋3検査日案を採用していない。
既存S1/S2/NERVの件数要件を緩めたり、frameを別Experienceへ水増ししたりはしていない。
日末Sleepは専用の有限な記録整理であり、身体睡眠・寝床・夜・一般Deep Similarityは未実行。

4日目の再試行は明示的な検査Probe。未採用候補を通常の学習済み判断と呼んでいない。
採用済みM_Bが実行へ効いたのは5日目。初版はこの明示検査1回・モデル採用1回まで。
日末の`tentative_route`は保存済みの元候補を指し、再形成や再採用の加算ではない。

T1-Aはcanonical4件＋候補1件＋Experience2件の7材料。
T1-Bは親M_Bと検査済みCandidateをRETAIN、残る材料はDEFER。
T1-Cのartifactはinspect/adoptで同一材料なら同一。cutover公開記録は1件。
review入口は本人の実際の初期Food未観測→初回Food観測の個数差で、harnessの明示reviewを使う。
この個数差だけを経路の検査結果、報酬、自動Hへ変換したわけではない。

REJECT（比較条件が揃う終点でFoodなし）、DEFER（姿勢/観測対応不足・取得不完了）、
採用済み経路の途中中断、材料改変、形成/検査の混線、日末途中失敗はPython合成試験で検査した。
これらを実Worldの負例として実行したとはしない。

## 配送回帰と検証

追加のL13S faults 1run・64取得は、受理後応答消失→同frame再送new_frames=0、
callback遅延、旧callback再注入、expired2件・stale1件の身体作用なしを検査した。
この専用故障runは1日の予算で未発見終了。実ネットワーク切断ではなくcallback故障注入。

L13S合計は**24独立実World日・1,536取得**（主20＋共有履歴分岐の新規3＋faults1）。
加えて旧L13A faultsを実機再実行し、42取得・移動37node・実pickup成功を確認した。
旧L13Aの固定探索挙動は変更していない。合計25実run、各24件の既存Lua adapter assertionもPASS。

- L13S Python: **20 PASS**。保存済み全World記録の再生、共有履歴対照、HTTP入口、故障回帰を含む。
- 全体: **716件実行＝665 PASS＋51 intentional skip**、19.063秒。
- 30日終了時の0/1/2回保持、30日目の3回目、31日目拒否、再送による非加算はPythonで検査。
  新L13Sで30日未達の実機系列を走らせたとはしない。
- 既存L13Rの62run等は全体テストの保存済み再生。今回、それら全てを実機再実行したわけではない。

## 再現と保存

```powershell
python -m integrations.luanti.tests.run_learned_exploration --scenario straight --modes record inspect adopt --seed 20260927 --max-days 30 --output integrations/luanti/output/l13s-main.json.gz
python -m integrations.luanti.tests.branch_learned_exploration integrations/luanti/output/l13s-main.json.gz integrations/luanti/output/l13s-shared-history.json.gz
python -m integrations.luanti.tests.run_learned_exploration --scenario faults --modes record --max-days 1 --output integrations/luanti/output/l13s-faults.json.gz
python -m unittest discover -s tests -p test_learned_exploration.py -v
```

gzipは無改変のWorld snapshot JSON tree・HTTP wireと、生成された系列記録を保存する。
元snapshotのSHA-256と内容一致、実行開始時の実装SHA-256をcapture時に検査した。
共有履歴の複製は同じrun IDで識別し、独立run数へ加算していない。
再生checkerはcanonicalのPython tupleをJSON配列へ正規化して比較する。実行後にこの比較を修正したが、
入力・World記録・HTTP応答・実行時の方策は書き換えていない。
fixtureは1,619,266 bytes。headless実機であり、GUI/ブラウザーによる視認検証ではない。

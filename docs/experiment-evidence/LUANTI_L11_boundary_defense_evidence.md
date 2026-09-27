# Luanti L11 — 固定関係・反復間隔による境界防衛 Evidence

**PASS / 2026-09-27。実Luanti 5.17.0 / 実Runtime HTTP。**
基準 `d3bf00d0` に本実装差分を適用。[固定契約](../experiment-contracts/LUANTI_L11_boundary_defense_contract.md)。

同じ1単位取得でも、固定された関係による閾値差と反復間隔によって警告表示の有無・発生順が変わった。
主比較24独立run・56 pickup・56評価・10警告許可・10実表示。別集計の同席／範囲外2runもPASS。
関係を経験から学んだ結果ではなく、現在の使用評価から有限な反応を出す機構の受入である。

## 入力と実装境界

`BoundaryDefense` はrunごとに設定を凍結し、本人・相手・餌場・行為のscopeを検査する。
通知・作用event・Food単位・前後packetの別名による再計数を拒否する。
8通知まで、警告許可1件まで。検証と計算を完了してからstateを置き換え、完全再送は既存receiptを返す。
有限台帳はprocess内だけであり、再起動を越える保証ではない。

既存近景SensorFrameは件数だけなので、誰が取ったかをそこから推測しない。
専用Luanti adapterが実pickupを計測し、前後の本人向け近景packetと結び付ける。
既存profileの近景半径を使うが、**汎用的な視覚行動認識ではない**。
今回のA/B profileは `fixture-life-sensory` / `fixture-life-sensory-compact`、revision 1。
現行profile定義では両方の近景半径は12。個体別profile参照を保ち、聴覚感度差は今回使用しない。

Runtimeの再生入力は設定・bounded前後packet・計測作用・通知・警告結果のみ。
Worldの絶対座標、期待結果、親子／敵／所有ラベル、他個体のM_Bは評価入力に入れない。
World座標とentity除去・取得済み数は実験者側Evidenceに分け、Python checkerだけが期待条件を検査する。
相対位置と距離は本人の局所半径内でのみ通知packetに含める。

## 主比較

表は**警告表示が発生した使用番号**。A/B役割交換の両方で同じ結果だった。
`—`は全予定通知の評価完了・閾値未到達であり、失効・未取得・取得不能を含まない。

| beneficiary inclusion | 基準閾値 | 有効閾値 | single | dense | spaced |
| --- | --- | --- | --- | --- | --- |
| 0 | 3 | 3 | 1 | 1 | 1 |
| 0 | 9 | 9 | — | 3 | — |
| 1 | 3 | 11 | — | 3 | — |
| 1 | 9 | 17 | — | — | — |

増分は毎回4、解消率は毎秒1のまま。関係は有効閾値だけを8上げる。
内部は整数micro-unit、解消量は取得時刻の差で計算し、配送時刻や予定枠へ丸めない。
単発loadは4、denseは実取得間隔に応じて約4→7.75→11.5、spacedは全件4→4→4。
包含ありでもlower/denseでは警告し、親しい相手への無条件免除とはしていない。

各使用枠でFood entityを1個生成し、実remove後のObjectRef位置消失と相手の取得済み数+1を確認。
使用者は警告後も同じ予定列を続ける。警告による相手の理解・退避・使用抑止は検査していない。
両身体は固定配置で、並進・追跡・攻撃・負傷・摂食の身体効果は追加していない。

## 実表示と通信

HTTP callbackは受渡しのみ。World stepでrun/epoch/個体/餌場/notice/operation/期限を照合し、
副作用の前に一回権限を消費する。NPCのnametag propertyを`WARNING`へ設定してreadbackし、
250000µs経過後の最初のWorld stepで空文字へ戻して再度readbackした。
これは実entityの表示状態の検査であり、クライアント画面の描画・視認性を撮影した試験ではない。
表示開始はすべて元取得から1000000µs以内。ログだけの成功報告ではPASSにしない。

`npc_a / inclusion=0 / threshold=3 / dense`で、実Runtime受理後の最初の応答をLuanti側で破棄した。
同じ通知を先頭へ戻し、同じ取得時刻・event・packet参照で再送。
`new_event=true → false`、同一receipt、loadへの加算1回、実表示1回を確認した。
これはcallbackの故障注入であり、ネットワーク切断ではない。
表示実行後と完了後の旧callback再注入、他個体へ付け替えた許可、結果の再送も別に検査した。

## 対照と局所検査

- **同席対照（実World）:** Foodは存在するがpickupしない。使用通知0、負荷0、許可0、表示0。
- **範囲外対照（実World）:** 相手を距離16へ置いて実pickup1回。前後局所packetにactor/resourceなし。
  通知は`unavailable`、`actor_not_visible / resource_not_visible`。評価null、許可0、表示0。
  主比較56回へこの範囲外pickupを加算しない。
- **Python合成入力:** 部分取得、未登録relation/単位、前後資料欠落、作用不成立、取得後も資源が残る矛盾を
  取得不能として区別。順序逆転・期限・別scope・改変・容量超過は拒否し、公開stateを維持。
- **Lua代替adapter36アサーション:** scope/notice/operation/時刻の不一致、期限等号／超過、表示中再入、
  完了後再入、未来時刻／期限切れによる非実行を検査。各実Luanti runのsetupで同梱コードも実行。
  期限切れの実World runを主比較へ混ぜず、この分岐の検証範囲を局所試験とする。
- **Python23試験:** 上記に加え、数値とboolの同一視拒否、入力出力の分離、4thread/8再送で新規受付1件、
  HTTP無効時404／不正入力422、固定packet列の旧Action・InteractionHistory・canonical/T1・NERV・旧Outcome非介入。
  この非介入は同じpacket列の比較であり、異なるWorld展開の全状態一致を主張しない。

`defense_load`はCore Hではなく、警告閾値はCore θではない。
E（差）、assessment、M_delta、T1、学習済みM_Bの更新を自動生成しない。

## 受入の対応

| 契約項目 | 検証と結果 |
| --- | --- |
| 1・3・5 主比較と役割 | 24run・56 pickup、4×3表をA/B双方でPASS。名前変更はPython対照 |
| 2 増分・解消・関係 | 実時刻で全loadを再計算、関係差の同一入力対照もPASS |
| 4 取得不足・同席 | 実World2対照＋Pythonの部分／不足／未登録でPASS |
| 6 実警告と未完了の分離 | 10許可＝10表示、開始／消去readback。失効はLua/Python局所検査 |
| 7 再送・失効した応答 | 実HTTP応答破棄→再送、旧／他個体許可拒否、結果再送PASS |
| 8 境界値と有限性 | Python23試験・Lua36アサーション内でPASS |
| 9 既存状態非介入 | 固定packet対照PASS |
| 10 既存回帰 | 全体629件＝578 PASS＋51 intentional skip。L10C全5、OBS-9 faults実機PASS |

## 再現と保存

```powershell
./integrations/luanti/scripts/test-boundary-defense.ps1 -Matrix
python -m integrations.luanti.tests.capture_boundary_defense_replay <出力されたmatrix manifest>
python -m unittest discover -s tests -p test_boundary_defense.py
python -m unittest discover -s tests
```

[固定再生JSON](../../tests/fixtures/luanti_l11_replay.json)は26runの入力・応答wire・World記録を改変せず保存する。
[checker](../../integrations/luanti/tests/check_boundary_defense.py)の`replay`へ渡すのはHTTP要求だけであり、
World正解や期待条件を評価器の補助辞書にしない。出典に元snapshot名・SHA-256と取得時の実装作業ファイルの
SHA-256を記録した。これらは取得時バイト列のハッシュで、Git blob IDではない。

実機回帰（本変更で再実行、旧fixture共有制御は変更なし）:

| 試験 | 出力snapshot | 結果 |
| --- | --- | --- |
| L10C both_active | `l10c-both_active-20260927-071041-689.snapshot.json` | A/B 10試行・6deposit |
| L10C neither_active | `l10c-neither_active-20260927-071104-444.snapshot.json` | A/B 12試行・6deposit |
| L10C a_only | `l10c-a_only-20260927-071126-786.snapshot.json` | A 10/5、B 12/7 |
| L10C b_only | `l10c-b_only-20260927-071149-258.snapshot.json` | A 12/7、B 10/5 |
| L10C reversed_cues | `l10c-reversed_cues-20260927-071212-129.snapshot.json` | A/B 10/6 |
| OBS-9 faults | `obs9-20260927-071235-229.snapshot.json` | 108frame、A/B生活完了、reobserved、障害回復PASS |

L11は固定関係が反応へ効く有限な機構としてここで止める。関係そのものの形成・独立検査・採用、
所有／親子／意図の認識、警告への相手の学習、既存Food生活への常設統合は未接続。

## 主比較の実run対応

全IDに共通の接頭辞は`l11-`。詳細な取得時刻と表示結果は上記JSONに保存。

| defender | inclusion / 基準閾値 | schedule | run ID | 警告使用番号 |
| --- | --- | --- | --- | --- |
| npc_a | 0 / 3 | single | `l11-npc_a-0-3-single--20260927-071319-836` | 1 |
| npc_a | 0 / 3 | dense | `l11-npc_a-0-3-dense--20260927-071321-928` | 1 |
| npc_a | 0 / 3 | spaced | `l11-npc_a-0-3-spaced--20260927-071324-328` | 1 |
| npc_a | 0 / 9 | single | `l11-npc_a-0-9-single--20260927-071336-227` | — |
| npc_a | 0 / 9 | dense | `l11-npc_a-0-9-dense--20260927-071338-727` | 3 |
| npc_a | 0 / 9 | spaced | `l11-npc_a-0-9-spaced--20260927-071341-625` | — |
| npc_a | 1 / 3 | single | `l11-npc_a-1-3-single--20260927-071353-564` | — |
| npc_a | 1 / 3 | dense | `l11-npc_a-1-3-dense--20260927-071356-031` | 3 |
| npc_a | 1 / 3 | spaced | `l11-npc_a-1-3-spaced--20260927-071358-419` | — |
| npc_a | 1 / 9 | single | `l11-npc_a-1-9-single--20260927-071410-418` | — |
| npc_a | 1 / 9 | dense | `l11-npc_a-1-9-dense--20260927-071412-318` | — |
| npc_a | 1 / 9 | spaced | `l11-npc_a-1-9-spaced--20260927-071414-726` | — |
| npc_b | 0 / 3 | single | `l11-npc_b-0-3-single--20260927-071426-676` | 1 |
| npc_b | 0 / 3 | dense | `l11-npc_b-0-3-dense--20260927-071429-175` | 1 |
| npc_b | 0 / 3 | spaced | `l11-npc_b-0-3-spaced--20260927-071432-096` | 1 |
| npc_b | 0 / 9 | single | `l11-npc_b-0-9-single--20260927-071444-057` | — |
| npc_b | 0 / 9 | dense | `l11-npc_b-0-9-dense--20260927-071446-011` | 3 |
| npc_b | 0 / 9 | spaced | `l11-npc_b-0-9-spaced--20260927-071448-433` | — |
| npc_b | 1 / 3 | single | `l11-npc_b-1-3-single--20260927-071500-337` | — |
| npc_b | 1 / 3 | dense | `l11-npc_b-1-3-dense--20260927-071502-297` | 3 |
| npc_b | 1 / 3 | spaced | `l11-npc_b-1-3-spaced--20260927-071504-678` | — |
| npc_b | 1 / 9 | single | `l11-npc_b-1-9-single--20260927-071516-589` | — |
| npc_b | 1 / 9 | dense | `l11-npc_b-1-9-dense--20260927-071519-060` | — |
| npc_b | 1 / 9 | spaced | `l11-npc_b-1-9-spaced--20260927-071521-449` | — |

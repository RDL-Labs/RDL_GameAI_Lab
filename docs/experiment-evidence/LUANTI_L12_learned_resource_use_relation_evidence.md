# Luanti L12 — learned resource-use relation / warning Evidence

**状態: IMPLEMENTED / FINITE ACCEPTANCE COMPLETE。**
基準: GameAI `a7450ce` ＋ 本実装のworking tree。2026-09-27。
契約: [L12](../experiment-contracts/LUANTI_L12_learned_resource_use_relation_contract.md)。
意味参照: Core `86a0d4f3`、BASE v2.3.1 / SPEC v2.5（E = Difference / 差）。

## 実行した経路

`ResourceUseLearning`は明示opt-inのloopback専用adapter。
本人向けの相手pickup通知と、その後の本人の実pickup結果から1 Episodeにつき最大1 Experienceを残す。
3件の形成材料が同じ取得結果を持つ場合に、`resource-use-continuation-v1`候補を形成し、
別の3 Episodeで独立検査する。全件比較可能かつ一致ならRETAIN、比較可能な反例があればREJECT、
不足があればDEFER。負の取得予測も同じ条件でRETAINできる。

既存canonicalのT1-A、T1-B、T1-C、inactive artifact、明示cutoverを実行する。
`current_M_B`はRETAIN、候補は計算したdisposition、他の材料は理由付きDEFER。
REJECT／DEFERでもT1-Bを記録し、再構成とcutoverは行わない。
Hの入口は最初の相手pickup前後の同じbounded packetによるcount差1→0に対する
**試験側の明示review**であり、Experience数・失敗回数・警告負荷からHを作らない。

`FrozenGameAIMB.interpret_resource_use`はactive model内のtyped relationだけで予測する。
positive RETAIN + cutoverでは取得1、negative RETAIN + cutoverでは取得0、
inactive／REJECT／DEFERはunknown。入力不足・適用範囲不一致・矛盾したrelationはunavailable。
正の予測なら固定consumerが閾値を3→11へ変える。それ以外の完全な未知・負の予測は基準3。
unavailableは評価も警告許可も出さない。+8は設計者固定値で、学習した数値ではない。
L11の固定`beneficiary_inclusion`を更新する処理はない。

## Worldと計測範囲

同じFoodの論理unitを、site→相手の手→返却site→本人の手へ移す。
保持条件ではsite→相手の手で止まり、本人は実際に試行して取得できない。
各段階でsite・相手・本人の合計が1であること、実entityの除去、手の数量、
実時刻と一回の作用権限を確認する。Episodeごとに物理状態を初期化し、学習状態と時計を保持する。
相手の返却／保持はharnessが指定し、相手が自律学習した行動ではない。

観測者A/Bを交換した独立runを使う。位置は観測者(0,1,0)、相手／Food(1,1,0)、
A/Bそれぞれの固定profileを維持する。近景の使用通知はL11同様の専用計測adapterであり、
一般視覚から行為・相手の意図・所有権を認識したとはしない。

最終Episodeは全条件で同じ返却予定を実行する。警告は返却前に開始し、
表示が相手の行動予定を変える経路はない。`WARNING`は実entityのnametagを変更し、
readbackと250ms後以降の最初のWorld stepでの消去を確認する。
Worldの絶対座標・返却予定・scenarioラベルはEvidenceと検査器だけで使う。
Runtimeのrun IDは条件名を含まない時刻識別子。予測より後の本人結果を先渡ししない。

## 実測結果

実Luanti 5.17.0（Windows / LuaJIT 2.1）、12独立run、84 Episode。
相手pickup 84回、本人の実試行84回、本人の実取得58回。
合計336 bounded packet、警告許可10件・実WARNING表示10回。全runが35秒以内に完了。
最短／最長のrun時計は15,781,635 / 15,792,071 µs。

| scenario | 検査 | 採用 | 現在予測 | 閾値 | 実警告 A/B |
| --- | --- | --- | --- | --- | --- |
| positive_active | RETAIN | cutover | 1 | 11 | 0/0 |
| positive_inactive | RETAIN | inactive | unknown | 3 | 1/1 |
| negative_active | RETAIN | cutover | 0 | 3 | 1/1 |
| negative_inactive | RETAIN | inactive | unknown | 3 | 1/1 |
| heldout_counterexample | REJECT | なし | unknown | 3 | 1/1 |
| heldout_incomplete | DEFER | なし | unknown | 3 | 1/1 |

検証結果:

- L12 Python: **26 PASS**（実記録再生・同一入力cutover対照・参照名変更を含む）。
- 実Luanti内Lua: 作用台帳**27 assertions**、共有L11警告controller **36 assertions**、各run PASS。
- 全体Python: **655件実行 = 604 PASS + 51 intentional skip**。655件すべてPASSとはしない。
- 既存実Luanti: **L11全26run、L10C全5scenario、OBS-9 faults、L10全3対照、L10B全3scenario PASS**。
- `git diff --check`、変更文書のローカルリンク282件、再生記録に固定した実装SHA-256の一致を確認。

最終L12 manifest: `l12-matrix-20260927-081809.json`。
既存実機回帰のconsole記録は `integrations/luanti/output/l12-regression-{l11,l10c,obs9,l10,l10b}.log`。
これらoutputはローカル実行物であり、配布する正本は出典付き再生JSON。


各runは7 Episode、28 bounded packet。形成support=3と検査件数=3を合算しない。
不完了対照は実Worldでは本人取得が成功しても、本人結果のcoverageを故障注入でpartialにし、
学習側では`acquired=null`としてDEFERする。完全なWorld正解で穴埋めしない。

正の予測が採用された現在結果は1→1、負の予測が採用された現在結果は0→1。
同じ判断時M_BでそれぞれE=0、E=+1を保存する。unknownはE=null / not_comparable。
これをcount境界のH・警告load・次のT1へ自動変換しない。

## 対照・故障・再生

- active/inactiveの実World対照に加え、positiveの同じ受理済み6経験と同じ最終noticeを二つのRuntimeへ再生。
  cutoverだけを無効化すると閾値11→3、警告許可なし→あり。実run間のwire同一性とは別のPython検査。
- Episode・actor・site・source等の参照名を一貫して付け替えた再生でも、disposition・予測・閾値は同じ。
  A/B交換は実World、参照名変更はPython再生。artifactハッシュの一致は要求しない。
- positive_inactive/Aでcallback受渡しを100ms保留し、受理済み応答を一度捨て、同じnoticeを再送。
  `new_event=true→false`、取得時刻と期限・Experience・load・警告数は増えない。
  実ネットワーク切断ではなくcallbackの故障注入。
- learnの再送、表示結果の再送、古いnotice／他個体／消費済みpermitを検査。
  callbackは受渡しだけで、World stepが権限を消費してから身体作用を行う。
- Pythonでは各T1 phaseの前／保存後に失敗を注入し、同じ凍結要求から再開。
  bundle・selection・artifact・cutoverは各1件。途中失敗を完了と返さず、beginを拒否する。
  selectionは保存後の応答消失も既存revisionと内容を照合し、二重記録しない。

再生記録: [luanti_l12_replay.json](../../tests/fixtures/luanti_l12_replay.json)。
受理済み要求・Runtime応答wire・World証拠を変更せず格納する。
元snapshotファイル名とSHA-256、実装ファイルSHA-256、基準commitをprovenanceへ記録する。

## 実行方法

```powershell
./integrations/luanti/scripts/test-resource-use-learning.ps1 -Matrix
python -m integrations.luanti.tests.capture_resource_use_learning_replay <matrix-manifest.json>
python -m unittest discover -s tests -p test_resource_use_learning.py
python -m unittest discover -s tests
./integrations/luanti/scripts/test-boundary-defense.ps1 -Matrix
# L10C: both_active / neither_active / a_only / b_only / reversed_cues
./integrations/luanti/scripts/test-sensory-learning.ps1 -SharedScenario both_active -TimeoutSeconds 90
./integrations/luanti/scripts/test-observation-v1.ps1 -Scenario faults -TimeoutSeconds 60
# L10: inactive / active / reversed active; L10B: opposite / a_only / b_only
./integrations/luanti/scripts/test-sensory-learning.ps1 -Activate $true
./integrations/luanti/scripts/test-sensory-learning.ps1 -MultiScenario opposite
```

## 停止点

本人の経験から形成・独立検査・採用した、相手／餌場／用途付きの取得予測が有限警告を変える。
親密さ・所有・意図・子供を認識した、関係が一般化した、警告で相手を学習させた、とはしない。
明示reviewと取得手順、+8のconsumer、相手の行動予定は固定。
自律的な問い・review・睡眠、二回目の再学習、長期関係変動、NERV由来の選別傾向、
全感覚生活への常設統合は未接続。プロセス内の有限台帳であり、永続化・再起動保証はない。

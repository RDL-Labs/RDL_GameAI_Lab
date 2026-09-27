# SOC-3 選別結果による次の救助Episode Evidence

状態: **PASS / 同一経験・固定選別条件差から有限な実行差へ** / 2026-09-27。
実装開始点: `7224d45`。[契約](../experiment-contracts/SOC_3_selection_guided_rescue_contract.md)。

## 成立した差

[SOC-2の実Godot記録](../../tests/fixtures/soc2_godot_replay.json)の共同成功2 Episode・失敗1 Episodeを、
変更せず各runへ渡した。保存済みdispositionを入力せず、既存SOC-2評価器で再検証・再評価して固定する。
主比較の厳格側0/1と許容側1/3は、同じ過去Experience・現在World条件・順位付けを使う。
選別でjointを候補へ残せるかだけが変わり、実際の次Episodeの選択と作用結果が変わった。

| 新Episode | 元のjoint判定 | 初手 | solo試行 | joint試行 | 結果 | deliveryまでのaction |
| --- | --- | --- | --- | --- | --- | --- |
| strict | REJECT | solo | 1 | 0 | 実carry失敗 → defer、目標未達 | null |
| tolerant | RETAIN | joint | 0 | 1 | carry → delivery、Recovery完了 | 11 |
| helper-absent | RETAIN | solo | 1 | 0 | 実carry失敗 → defer、目標未達 | null |

全行動決定は4 / 12 / 4。許容側の12件には完了確認idleを含む。
未達側の行動数が少ないことは救助効率の改善ではない。
厳格側も過去jointの成功2・失敗1と全出典を保持する。除外した経験を消す処理ではない。
今回の4 event（1 / 2 / 1）は別のcurrent領域へ保存し、過去のfailure_count=1、validation_count=3やevaluation_idを変更しなかった。
新Episodeの成功で過去判定を再学習するcycleは作っていない。

## Worldの条件と実行経路

実Godot 4.7.2 headlessと既存Rescue HTTP経路を使った独立3 run。
World、Rescue Runtime、通常InteractionHistory、canonical sidecar、操作台帳は毎回新規にした。
A/Cの搬送能力各1、B荷重2は実験者側へ隔離した。Bは既存fixtureの3回のfleeにより行動不能になる。
主比較2 runの記録した初期位置・B身体状態・carry試行0・Experience0は完全一致する。
三つ目だけCを参加距離外へ置く対照であり、主比較と同じ現在World条件だとは扱わない。

`SelectionGuidedRescueEpisode`はjointの候補制限と現在の実行可能性を別々に検査する。
候補を残した後はSOC-1から抽出した共通関数で、過去delivery成功数、失敗数、solo優先の順に並べる。
Godot側へprofileを環境変数として渡していない。選択応答には根拠が含まれるが、身体adapterは
profile名や許容値でsolo/jointを決めず、選択結果とbinding・現在条件を検査する。

新しい`/soc3/choose`はPythonテスト内の専用handlerだけに存在し、既定bridge endpointではない。
Godot adapterが現在のA/Bの身体条件・Cの参加距離を実行可能性リストへ変換する。
荷重・能力・必要人数は選別入力や通常Runtime packetへ渡さない。
選択後は既存Rescueがapproachし、実carry直前に参加条件を再確認する。
jointへの参加設定と同期移動はharness/既存SOC-0 fixtureが担い、自律的な援助要請ではない。

許容側ではBをplazaへ実配送し、stabilizing → mobilizing → recovering → recoveredを確認した。
厳格側とC参加不能側ではBの前後位置が同じで、attachは発生しない。
soloが失敗すると今回のsoloを除外し、jointの選別結果や現在不可を解除せずdeferになる。
harnessがそこで追加のRuntime行動要求を停止する。
既存Rescue commitmentは成功扱いで解放されず、監査記録に`rescue_goal_status=pending`とBが残る。
これは終了した有限試行の未達記録であり、永続Goal待機・再開機能ではない。

過去選別のREJECTと今回Episodeのdeferredは異なる層の結果である。
未実行jointやdeferに失敗eventは作らない。C参加不能でもjointを「試して失敗した」とは数えない。

## 因果参照と一回実行

各作用eventにchoice ID・event ID・actionのsource observation・action名を持つexecution_refを付ける。
approachを挟むため、選択時の観測IDと実carry時の観測IDは同じとは限らない。
実行ログがchoice → action → eventを結び、carryとdeliveryには同じchoice参照を要求する。
過去3 Episode最大6 eventと現在最大3 eventを別々に検証する。
最大3 choice、各条件一度の最大2 carry試行、最大30行動決定で終了する。

全3 runで同一選択要求をHTTP再送して同じ結果を得た後、Godotへ再適用しても状態が変わらないことを確認した。
二つ目の選択がある厳格側・C参加不能側では、最初の要求を再送し古い応答を再注入しても新しい選択を置き換えない。
選択再適用の拒否検査は3 / 1 / 3回。全runで終端後の再適用も拒否した。
別に、実行したrescue decisionを各runで一度ずつ再送し、身体状態・位置・試行数・Experience・台帳が不変だった。

実Godot内の**直接guard試験**も実行した。これは選択を局所注入した検査であり、追加のHTTP Episodeや学習結果には数えない。

- joint選択後にCを距離外へ移す、またはAを行動不能にする。carry直前に停止し、試行0・event0・B非移動。
- joint実失敗後、別action sourceでも同じchoiceを消費できない。試行数・event数は1のまま。
- 他runのbindingと閉じたEpisodeの選択応答は適用しない。

任意の通信遅延・並行World割込みやプロセス再起動後の永続的一回実行保証は対象外。
作用列のtickは既存fixture同様0で、Recovery時にWorldをstepする。順序はevent列と観測参照で記録する。
choiceのハッシュと既存record IDは整合性・同一入力の識別用で、署名ではない。実行証拠の報告はadapterが担う。

## Python境界試験と保存再生

[出典付き再生JSON](../../tests/fixtures/soc3_godot_replay.json)には、各runの元入力、実World出力、
全choice呼出し、現在の受付・終端、既存Rescue状態を保存した。
保存済みchoiceは元入力から完全再計算し、終端snapshotまで一致した。Worldの作用結果は加工していない。

以下は実3 runと区別したPython試験。

- 全成功／全反例では両profileの選択が一致。過去DEFERはpartial反例を保持し、判定用joint件数はnull。
- 現在文脈不足はdefer。現在不可・今回失敗・選別除外の複数理由を同時に保持。
- profile名・Episode名による分岐なし。順位の成功数・失敗数・同点境界を検査。
- 2条件失敗後の3番目choiceでdefer。4番目choice、4 eventを明示拒否。
- 同choice内容変更、別binding、過去event、event列prefix変更・省略、時刻逆行を拒否。
- event名を変えた同action sourceの再計上、未選択条件、carryなしdelivery、参加者混線を拒否。
- 再選択に新失敗を要求し、attach後は再選択不可。attachだけのincompleteを失敗や完了へ変えない。
- 不正入力で受付・選択台帳の部分更新なし。入力・返却値変更が保存状態に波及しない。
- 終端を凍結し、新choice/event/finishで再開不可。同じ古い要求の再送は読み取りだけ。

固定3 packetでは明示SOC-3呼出しの有無による既定Action・InteractionHistory・canonical snapshotの一致を確認した。
再構成呼出しを禁止するguardも通った。実3 runのcanonical T1材料数は0。
これは変更された実World行動列同士が一致するという検査ではない。
SOC-1は順位付け抽出だけで、保存済み旧choiceの完全再生と実World保持比較を通した。SOC-2評価器は変更していない。

## 受入の対応

| ID | 結果と検証経路 |
| --- | --- |
| S3-01 | PASS: 同じSOC-2材料の再検証、episode_results一致、反例・元集計の保持 |
| S3-02 | PASS: 同初期Worldの厳格solo失敗→deferred / 許容joint→completed |
| S3-03 | PASS: 実C距離外の対照、直接Godotの実行直前条件喪失、Pythonの複数理由 |
| S3-04 | PASS: Pythonの全成功・全反例・過去DEFERの対照 |
| S3-05 | PASS: 共通順位付け、名前不変性、同点規則、harnessは選択応答を適用 |
| S3-06 | PASS: 厳格側joint非復活・未試行・未達を記録、attach未完了はPython試験 |
| S3-07 | PASS: 独立予算、実行参照、各種改変・容量拒否と非部分更新 |
| S3-08 | PASS: HTTP選択再送、古い応答非適用、実action再送、終端固定・競合拒否 |
| S3-09 | PASS: 新結果の元評価非混入、deepcopy、旧SOC-1/2保存再生 |
| S3-10 | PASS: 下記の実Godot回帰・全体試験、NERV/T1非接続、検証経路別記録 |

## テスト結果と再実行

```text
SOC-3専用: 21 PASS（Python局所19＋保存再生1＋実Godot 3 runを含む1試験）
SOC-3 + SOC-2 + SOC-1 + SOC-0 + 既存Rescue: 62 PASS
全体（GODOT_BIN未設定）: 541件実行 = 491 PASS + 50 intentional skip
```

62件の内訳は21 + 20 + 13 + 4 + 既存Rescue 4。
SOC-2の共同成功/成功/失敗、SOC-1の保持ありsolo/joint/jointと保持なしsolo/solo/soloも実機で再確認した。
全体skipにはこれら外部実機試験を含むが、それらは上の実行で別途PASSしている。
全外部試験を再実行した意味ではない。Luanti・ブラウザー実機は今回再実行していない。

専用21件の再実行（PowerShell、リポジトリroot。Godotのパスは環境に合わせる）:

```powershell
$env:GODOT_BIN = 'D:\Godot\Godot_v4.7.2-stable_win64_console.exe'
$env:PYTHONPATH = 'tests'
python -m unittest test_selection_guided_rescue -v
```

全体はGODOT_BIN未設定の別shellで`python -m unittest discover -s tests -v`。
生ログは無視対象の`integrations/luanti/output/soc3-godot-regressions.log`と`soc3-full-tests.log`。

SOC-3は、設計者が固定した取捨選択条件による有限な行動差で停止する。
NERV-4DはDESIGN ONLYのまま。神経・身体からprofileを形成すること、援助要請、社会relation、canonical T1/M_B更新には進んでいない。

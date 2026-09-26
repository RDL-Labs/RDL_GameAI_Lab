# OBS-7B 隣接聴覚窓のパターン候補 — Evidence

実行日: 2026-09-26。実装開始基準: `92ee294d5bddf8f630fed2335b760c682308dd73`。
[契約](../experiment-contracts/OBS_7B_auditory_pattern_candidates_contract.md)の`obs7b-v1`を検証した。

## 実装と範囲

`runtime.auditory_candidates.find_candidates(snapshot, request)`は受理済みsnapshotと明示queryから
対象窓の全検出を検査する純粋関数。最大16query・32frame参照・128組。
単一候補でも音源同一性を意味しない。強度・temporal_formは一致条件ではない。
7Aの時間重なり規則を変更せず、7Bでは隣接窓の境界接触を別目的として扱う。

## 実Luanti取得・HTTP受理・replay

実行: `powershell -ExecutionPolicy Bypass -File integrations/luanti/scripts/test-auditory-candidates.ps1`

専用Worldで既存の伝達・窓センサーを使用し、8frameを4件ずつ実Runtimeへ送信。
両バッチともaccepted=true / new_frames=4。snapshotは8frame、拒否0件。
最終取得ファイルは`integrations/luanti/output/obs7b-20260926-100656-912.snapshot.json`。
そのsnapshot全体を改変せず`tests/fixtures/obs7b_luanti_replay.json`へ出典付きで保存した。

| ケース | 実際の取得条件 | 結果 |
| --- | --- | --- |
| 単一 | 同じ姿勢・窓境界を跨ぐmid音。異なる2位置から同cellへ混合 | single_candidate、1件 |
| 複数 | 次窓に隣接方向cellの追加音 | multiple_candidates、2件 |
| なし | 元の音は境界で終了、次窓は完全取得の空窓 | no_candidate、0件 |
| 比較不能 | 次窓に同姿勢の検出と、実際にyawを変えた取得姿勢の検出 | not_comparable、candidates=null |

最初の組は受信区間[245000,250000) / [250000,255000)、同じ検出取得姿勢、
方位bin[0,30]、mid帯域。7Bは単一候補、同じ組を7Aへ渡すと`no_temporal_overlap`。
最後の組はpair_resultsにcandidateとnot_comparableを保持し、理由は`pose_mapping_unavailable`。
既知の一件を完全な単一候補集合にしない。

harnessの出力:

```text
OBS7B PASS: single=1 multiple=2 none=0 incomplete=not_comparable 7A=no_temporal_overlap
```

生成側のevent IDやWorld位置はframeに含めず、比較器にも渡さない。
最初の混合ケースは異なる発生位置を分離できないことを保ったパターン候補であり、
同一音源を検証したものではない。構造化eventの有限fixtureであり、音声波形の入力試験ではない。
RW2への候補機能の組込みや、一般環境での追跡成功は主張しない。

## Python試験

`python -m unittest tests.test_auditory_candidates -v`: **18件PASS**。
実fixture replay、実store受理の合成正例、四状態、±180度・30度境界、
不完全coverage、未知方向・band・pose、空窓、profile/clock/model/sensor条件、
入力拒否と全体atomic性、16/17query境界、32frame・128組、再送new_frames=0、
順序・重複不変、出力コピーの独立性を検査した。

固定3packetの診断呼出しあり／なしで、action応答・Experience・canonical snapshot・
sensory storeが一致。これはPython固定入力の非介入試験で、実Worldの全行動列一致ではない。

`python -m unittest discover -s tests -v`: **360件実行 = 314件PASS + 46件の意図的skip**。

## 既存実Luanti回帰

`test-observation-integration.ps1`（OBS-6E）を再実行:

```text
OBS6 SENSORY: agents=2 channels=3 rejection_recovered=1 transport_retry=1 response_loss_retry=1 duplicate_new_frames=0 ack_only_removal=true life_compatible=true
OBS6 LIFE PASS: agents=2 pickups=2 deposits=2 results=2 radius_counts=A:2,B:1
```

`test-audition-observation.ps1`（OBS-4C）を再実行:

```text
OBS4C PASS: frames=6 cross_window_split=true duplicate_close_idempotent=true late_rejected=true detection_limit_partial=true
```

## 停止境界

新HTTP endpoint、GUI、action hook、姿勢変換、ランキング、勝者選択、支持数、
永続store、自動追跡、視線変更、canonical接続は追加していない。
ブラウザー確認は今回未実施。7Bを有限な記録リンク候補としてここで区切る。

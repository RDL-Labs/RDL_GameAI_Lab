# OBS-7B 隣接窓の聴覚パターン候補 — 契約案

状態: DESIGN ONLY / DRAFT v0.1 / 2026-09-26。
実装基準: `73caf0330a58d6e56b8640451804c25817825a5b`（OBS-7A）。
この文書は未実装・未検証。候補生成の完了や実Luanti正例の取得を主張しない。

## 1. 目的と問い

提案する目的名は `adjacent_window_auditory_pattern_candidates`、規則版は `obs7b-v1`。
問いは「同じ個体・聴覚基準で取得した隣接窓の中に、窓境界へ接する粗い音パターンの
対応候補があるか」。一つの基準検出に対し、明示した次窓の全検出を有限に検査する。

これは音源同定、音の意味、波形類似、実音の連続性の証明ではない。
単一候補も「この限定規則に適合する記録が対象窓内に一件」という結果に限る。
候補は観測要素間の局所的なリンクであり、canonical CandidateRelationではない。

## 2. 既存データからこの範囲を選ぶ理由

- `audition_window_sensor.lua`は窓を跨ぐeventを分割し、取得時の方向と姿勢参照を保持する。
- 一般的な連続追跡には姿勢変換が必要だが、同じ取得姿勢を保持した分割受信は既存schemaで表現できる。
- OBS-4Cは跨ぎ音を含む一方、後半窓にoverflowと回転がある。
  その現行出力は正例の代用品にせず、欠落・姿勢不一致の検査材料とする。
- RW2の`life_sensory.lua`はtick別pose参照と10msの行動音を生成する。
  通常RW2が本目的の正例を自然に出すとは仮定しない。
- eye/ear対応や任意の経時比較は今回必要ない。OBS-6Eの配送基盤を再設計しない。

重要な制約: 現行kernelは同じcellの受信を混合し、received intervalを最小開始〜最大終了で
表す。この区間は複数音の間の無音を含みうる包絡区間であり、全区間の連続発音の証拠ではない。
別の音源が同じcellへ混ざることもある。よって出力はパターン候補に留める。

## 3. OBS-7Aとの関係

[7A](OBS_7A_comparison_eligibility_contract.md)は取得時間の重なりを要求する。
本案は隣接した半開窓の境界で終わる／始まる記録を扱う別目的である。
同じ組が7Aで`no_temporal_overlap`になっても、それを失敗として救済しない。
7Aのpurpose、許可表、理由、テストは変更せず、新しい目的の契約と試験を分ける。
7Aの判定結果から理由を削って7Bの適格性に流用する方法は採らない。

## 4. 入力・有限予算・寿命

純粋関数の提案I/Oは `find_candidates(snapshot, request)`。
受理済みsnapshot、run_id、world_epoch、agent_id、purpose、rule_versionを明示する。
requestのqueriesにはsourceのframe_id/detection_idとtarget_frame_idを指定する。
暗黙latest・任意の全履歴探索・外部World検索はない。

1呼出しは最大16queries・32frame参照。各target frameは現行上限の8検出すべてを検査し、
最大128組の判定となる。対象検出の部分リスト指定は許可せず、都合のよい候補だけを選ばない。
同じqueryは一度だけ返すが、予算は重複排除前に検査する。
source→targetは時間方向を持ち、逆順を同じqueryとして扱わない。

入力不正は全体を拒否する: 未知ID、他個体/run/epoch、未知要素、重複して一意に解決できない
要素ID、同一frame、逆時系列、目的/規則版不正、上限超過。
有効な未来のtarget frameでも隣接していなければ比較不能とする。
frame/detectionのIDは不透明な参照で、文字列から時刻・音源・姿勢を推測しない。

新しい永続store・支持回数・候補統合は置かない。出力は指定したframe対だけに有効。
次の窓、別profile、別poseへ引き継ぐには新しいqueryが必要で、自動的な追跡IDを発行しない。
同じframeの再配送は新しい候補の証拠を増やさない。

## 5. 初版の適格条件案

| 項目 | 条件 |
| --- | --- |
| 所有 | 同一run / epoch / agent |
| channel / sensor | audition / ears、両側一致 |
| model | direct_band_energy_v0 |
| profile | fixture-audition-enabled、revision 1、両側一致のみ |
| 取得状態 | SAMPLED、COMPLETE_WITHIN_PLAN、output_limited=false |
| 時計 | 同一clock_id |
| 窓 | 両側interval、幅250000µs、source.end = target.start |
| pose | source検出と各target検出のobserver_frame_refが一致 |
| 要素 | 正のreceived interval、既知の30度azimuth bin、既知のelevation、low/mid/highのdominant band |

profileはまず既存の通常gain聴覚fixtureだけに限定する。生活profile等への拡大は別の検証後。
pose参照の意味はproducerが保証する取得基準に依存し、同じtickや似た文字列では代用しない。
未知方向、mixed/unknown band、未対応角度形式は比較不能として理由を残す。
frameが完全取得でも空のtarget payloadは有効な探索対象とする。要素間pose比較は発生せず、
この場合の候補なしは「その記録内に検出がない」に限定する。

## 6. 候補述語案

適格な組に対し、次のすべてを満たす場合だけリンク候補を返す。

1. source検出のreceived endが窓境界に一致し、target検出のreceived startが同じ境界に一致。
2. elevation_bandとdominant_bandがそれぞれ一致。
3. 方位bin中心の円周上の距離が30度以下。

初版は幅30度、端点が30度刻みで[-180,180]内にある区間のみ対応する。
中心c=(lower+upper)/2、d=abs(c1-c2)、円周距離=min(d,360-d)とする。
[150,180]と[-180,-150]の中心距離は30度なので候補になる。向かい合うbinは候補にならない。
同じbinだけでなく隣接binを含めるため、一つのsourceに複数のtarget cellが残りうる。

30度は既存profileの一bin分を許容するGameAI-localの探索規則案であり、物理的精度や
移動速度を推定した値ではない。実装時に規則版へ固定し、候補を出すために実測後に緩めない。
received_strength_bandはwindow分割・混合で変化するため一致条件に使わず、出典には残す。
temporal_formは現行kernelがbrief固定なので識別根拠に使わない。

候補外の適格な組にも、boundary_not_touched / band_mismatch / elevation_mismatch /
azimuth_outside_neighborhoodの不適合理由を記録する。これらを入力拒否や情報不足と混ぜない。
全候補を返し、score、確率、ランキング、勝者選択、一対一割当は作らない。

## 7. 結果の区別

| status案 | 条件と意味 |
| --- | --- |
| not_comparable | frame条件不成立、または対象検出に比較不能が一つ以上ある。候補数を確定しない |
| no_candidate | 対象窓の全検出を検査でき、適合0件。世界に音源が存在しないという意味ではない |
| single_candidate | 全検出を検査でき、適合1件。音源や出来事の同一性は未確定 |
| multiple_candidates | 全検出を検査でき、適合2件以上。複数を残す |

一件が適合していても、別の対象検出の姿勢が不明ならsingle_candidateと呼ばない。
not_comparableでも既に判定できた組の結果はpair_resultsに残せるが、完全な候補集合として返さない。
frame自体がPARTIALなら候補生成せず、入力参照と理由のみ返す。

出力にpurpose・rule_version・探索対象frame・source検出・全対象検出の判定・取得条件・
候補リンク・診断理由・探索完了の有無を保持する。全結果は入力から切り離したコピーとする。
理由コードの候補: unsupported_profile/model/channel/sensor、clock_mismatch、
non_adjacent_windows、unsupported_window、unavailable、incomplete_coverage、output_limited、
pose_mapping_unavailable、unknown_direction、unsupported_direction_bin、unknown_band、
unknown_elevation、empty_received_interval。
最終APIとエラーコードは実装時に本案へ同期し、曖昧な汎用error一つへ畳まない。

## 8. 実Luanti正例の取得計画

既存`audition_window_sensor.lua`と`audition_transmission.lua`を呼ぶ独立した有限fixtureを追加する。
OBS-4CやRW2の既存条件・期待値は変更しない。別の世界/設定で以下を実行する。

1. Aのprofileをfixture-audition-enabled、耳の位置とyawを固定する。
2. 開けた経路で245000µs開始・10000µs長のmid-band eventを発生させる。
   例として距離4・energy=0.8なら既存減衰と半分割後のmidは0.2となり、閾値0.05を超える設計。
   実際に両側で検出され、coverageが完全であることをharnessで確認する。
3. 姿勢を変えず、[0,250000)と[250000,500000)を一度ずつcloseする。
4. 実Runtimeで受理し、検出区間[245000,250000)と[250000,255000)、同じ取得姿勢・bin・bandを確認する。
5. 受理済みframeを変更せずJSONへ保存し、Pythonの純粋関数へ渡す。
6. single_candidateと、同じ組を7Aへ渡すとno_temporal_overlapになることを両方確認する。

eventのWorld位置や生成側IDはharnessの期待値だけに使い、比較器の入力には追加しない。
「fixtureで同じeventを分割した」という実験者の知識を、NPCの同一音源判定へ転用しない。
専用fixtureの成功はRW2に候補機能を統合した証拠ではない。

## 9. 受入試験計画と停止境界

| 試験 | 期待 |
| --- | --- |
| 上記の実Luanti二窓＋Runtime受理＋replay | 条件を改変せずsingle_candidate。7Aは時間重なりなし |
| 二窓の近い方向cell、同じband、境界接触 | 複数cellが閾値を超えるよう制御しmultiple_candidates。全件保持 |
| 完全な空窓／境界に触れない音／逆方向／異なるband | no_candidateと検査範囲・理由。世界の不在を主張しない |
| pose変更／未知方向／PARTIAL／上限打切り | not_comparable。既知の一候補を単一と断定しない |
| 異なる音源が同じcellへ混ざる | 分離不能のままパターン候補。source IDの漏洩なし |
| ±180度境界、30度／30度超、ゼロ長区間 | 円周距離と不正・比較不能の境界を固定 |
| 別個体/run/epoch、未知参照、逆順、16／17queries | 明示拒否と全体atomic性 |
| 再送・配送遅延・frame順変更 | 同じ取得記録から同じ候補。支持増加なし |
| 固定packet診断あり／なし | action・Experience・canonical・sensory store不変 |
| 既存7A＋OBS-6E＋OBS-4C回帰 | 既存契約維持 |

合成試験、実Runtime受理、実Luanti取得、replay、未実行の項目をEvidenceで分ける。
7Bを実装しても新しいHTTP endpoint、GUI、action hook、視線変更、目印同定、canonical接続は追加しない。

## 10. CoreとPhysics Labの参照位置

CoreのT1は候補展開・検査・選別・再構成を分ける。本案はGameAIの局所的な候補リンク規則であり、
T1全体の実装でも、F/F'比較によるE/H生成でもない。比較不能をξの数値へ変換しない。
Physics Labのモデル有用性の見方に従い、本規則を「どの目的・条件・予算で使えるか」で評価する。
物理解釈の仮説をCoreの定義や音響法則として追加しない。

参照版: RDL_Core `3270982`、RDL_Physics_Lab `cab5d86`。
本案の成果は次の実装範囲と正例条件を明示したことであり、7B機能の完成ではない。

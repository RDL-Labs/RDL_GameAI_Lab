# 感覚観測の解釈・利用への接続計画

状態: OBS-7Aの純粋診断、OBS-7Bの有限候補生成、OBS-8/8Bの専用Probeと継続World調停を実装 / 2026-09-26。
OBS-7Bは[隣接窓の聴覚パターン候補の契約](../experiment-contracts/OBS_7B_auditory_pattern_candidates_contract.md)と[7B Evidence](../experiment-evidence/OBS_7B_auditory_pattern_candidates_evidence.md)へ実装・検証結果を記録。
OBS-8は[同一視覚チャンネル内の再取得契約](../experiment-contracts/OBS_8_visual_reacquisition_contract.md)の専用fixtureと純粋評価を実装。
[8 Evidence](../experiment-evidence/OBS_8_visual_reacquisition_evidence.md)に検証範囲を記録。
[実装契約](../experiment-contracts/OBS_7A_comparison_eligibility_contract.md)と
[Evidence](../experiment-evidence/OBS_7A_comparison_eligibility_evidence.md)に7Aの到達点を記録する。
以下の提案・予定表現は設計時の記録。7Aの確定した目的・許可表・理由コードは契約を参照。
基準: `23d4d2ad21a4b2d1ea662875d38572c8b4428bd4`。
本稿はGameAI-localの設計であり、実装・検証済み機能やCore定義を追加しない。

## 1. 固定する到達点

[OBS-6 Evidence](../experiment-evidence/OBS_6_integrated_life_regression_evidence.md)
と[契約](../experiment-contracts/OBS_integrated_life_regression_contract.md)を、短いRW2生活試験の観測基盤として固定する。
個体別近景・遠景・聴覚、取得時刻・coverageの保持、有限配送、拒否・送信前失敗・
受理後の応答消失からの再配送、重複保存防止、明示ack後のpending除去が対象。
応答消失は実Luanti callbackでの注入であり、実ネットワーク切断試験ではない。
RW2互換は有限生活Acceptanceの完了を指し、全行動列一致ではない。

観測基盤の追加整備はここで閉じる。長期運転、永続化、保持・圧縮、実ネットワーク障害、
嗅覚、動的profileは別課題とし、解釈側の着手条件に追加しない。

## 2. 次に答える問い

最初に問うのは「この個体が取得した二つの記録について、何を根拠に比較できるか」。
「同じ音源である」「危険である」「こちらへ進むべき」はこの段階の結論にしない。

| 段階 | 作るもの | 状態・終了条件 |
| --- | --- | --- |
| OBS-7A | 比較適格性の診断 | 実装・検証済み。時刻・姿勢・profile・coverage・出典を検査し、比較不能の理由を保持 |
| OBS-7B | 隣接窓の聴覚パターン候補 | 実装・検証済み。専用実Luanti fixtureで四状態を再生。比較不能と候補数を区別 |
| OBS-8 | 同一視覚チャンネル内の再取得 | 専用fixture・評価を実装。実測姿勢対応、1回の水平回転と通常周期取得。7Bを起動条件にしない |
| canonical接続 | 有限断面と解釈モデルの選択 | 別契約。7A/7Bの結果をそのままF・E・HやCandidateRelationへ昇格しない |

OBS-8Bの明示起動・生活優先fixtureで一度区切る。生活中の自動起動・聴覚連携・canonicalへの機能拡張は行わない。

## 3. 現在使える情報と不足

`runtime/sensory_observation.py`の受理済みframeを唯一の入力元とする。
run・epoch・agent、frame ID、channel、profile版、sensor model版、clock、
capture window、sampled tick、observer frame参照、status・coverage・output limitを参照できる。
遠景は方向区間・粗い見え方、聴覚は検出ごとの受信区間・姿勢参照・粗い方向と強度を持つ。
近景の既存Food/Base IDは既存経路の限定情報であり、遠景や音への結合キーにしない。

現行の`observer_frame_ref`は参照文字列であり、姿勢変換そのものではない。
遠景のeye-poseと聴覚のear-poseは、同じtick番号でも共通方向基準を保証しない。
聴覚ではframeのwindow参照よりも検出ごとの取得時姿勢を使う必要がある。
IDの文字列解析、配送時点の姿勢、World内部座標から不足する変換を作らない。

したがって初版で異なる姿勢参照の方向比較が`not_comparable`となるのは正常。
将来の正例には、有限な姿勢対応の出典・取得時刻・誤差・失効条件を別途定義する。
そのために既存frame schemaへ真の音源IDやWorld方位を追加しない。

## 4. OBS-7Aの最小設計

### 入力と予算

実装候補は、immutableな受理済みsnapshotと明示されたframeの組を受け取る純粋な診断関数。
`/v1/observe`のaction応答や保存処理へ自動挿入せず、最初は固定replayから呼ぶ。
1呼び出しは同一agentの最大16組、frame参照は最大32件とする提案。
全履歴の直積、暗黙latest選択、無制限catch-up、別の永続storeを作らない。
上限超過は全体を明示拒否し、未検査分を「候補なし」にしない。
具体値は性能の実測値ではなく、最初の実装契約で固定する有限予算。

入力にはframe IDと必要ならfeature/detectionのframe内ID、比較目的、診断ルール版を指定する。
同一snapshotと同一入力からは配送順に依存しない同一結果を返す。
同一frameの再送を新しい証拠として数えず、同一frame自身との組は診断対象から除外する。

### 出力

提案する出力は`eligible` / `not_comparable`の判定、複数の理由コード、
両側のframeと要素の参照、ルール版、入力の取得条件。
`eligible`は指定した比較操作が可能という意味に限り、同一対象の認定ではない。
不正入力（未知ID、存在しない要素、他個体参照、予算超過）は診断の未知と区別して拒否する。
保存前のframeや拒否済みextensionを入力候補に混ぜない。

### 検査順序

1. 所有と出典: run / epoch / agentを固定し、参照先が実在することを検査する。
2. 時間: 同一clockの取得時刻を使用する。配送tickで再時刻付けしない。
   点と半開区間は`start <= point < end`、区間同士は正の重なりで判定する。
   初版は時間許容幅0の重なり検査だけを持ち、時間外はその比較目的について比較不能とする。
   聴覚は個々のreceived intervalを使う。時間外であることを対象の不在へ読み替えない。
3. 条件: profile/model版は比較ルールが明示的に許可した組だけを扱う。
   同一文字列であっても異なるchannelの意味が等しいとはしない。版の変化を学習差と呼ばない。
4. 取得状態: UNAVAILABLE、PARTIAL、output_limitedは理由を残す。
   初版では完全取得を要求する比較のみ許可し、不完全な空配列を負の証拠にしない。
5. 方向: 同じ取得基準が保証された場合だけ区間比較を許可する。
   不明な聴覚方向や未定義の姿勢対応は比較不能。角度の周期境界を単純な大小比較で処理しない。
6. 特徴: 粗い色と音強度を同じ尺度で比較しない。対応規則のない特徴は欠落として記録する。

方向の互換性、時間の重なり、同一出来事の候補、恒久的同定は別の判定である。
7Aには候補スコアや確率を置かず、後段が判断できる条件・出典を残す。

## 5. 実装時の受入試験

以下は予定であり、この文書の作成で実行済みとはしない。

| 試験 | 期待結果 |
| --- | --- |
| 同一agent・clock・取得基準・許可した条件の組 | 適格性の正例。対象同一性は出力しない |
| 点が聴覚区間の開始／終了に一致 | 開始は含む、終了は含まない |
| 観測配送の遅延・順序変更・同一frame再送 | 取得条件と診断結果が変わらず、支持数も増えない |
| 異なるagent/run/epoch・未知frame/要素 | 明示拒否、他個体の結果に混入しない |
| eye/earの別姿勢参照、回転を跨ぐ組 | 未定義の変換を補わず比較不能 |
| UNAVAILABLE・PARTIAL・上限打切り・空payload | 不在や不一致として断定しない |
| profile/model版の差、異なるclock | 許可した比較規則がなければ比較不能 |
| 複数の方向候補、周期境界、不明方向 | 恣意的に一件を同定しない。未対応の比較は理由付きで停止 |
| 予算境界と超過 | 上限内だけ処理、超過は明示拒否 |
| 固定packetで診断有効／無効を比較 | 既存action応答・Experience・canonical状態に差がない |
| 実Luanti由来frameのreplay | 出典を保持し、姿勢対応不足も正常な結果として確認 |

合成正例、実Luanti由来replay、新規実Luanti実行の証拠を区別する。
現行実frameで感覚間比較が成立しない場合、合成データの成功を実Worldの照合成功と呼ばない。

## 6. 利用側へ進む条件

7Bでは「対応候補なし」「比較不能」「複数の対応候補」を区別する。
単一候補でも確定した音源・ランドマークとして保持しない。候補の寿命と再評価条件を先に決める。

8では最初の用途を追加取得のための視線変更候補に限定する案を検討する。
現在の姿勢への変換、鮮度、生活行動との優先順位、回転予算、終了・失敗、
再取得と効果確認を別契約にする。帰還経路・危険回避・Goal変更の権限はそこから推定しない。

canonicalへつなぐ場合はPurpose / B / Section_Bと入力断面、固定した更新前M_B、
F/F'の比較適格性を先に定義する。欠落・候補数・方向差を直接EやHへ入れない。
[Core参照](../semantic-reference/RDL_Core_T0_T1_reference.md)の既存境界を維持する。

## 7. 現在の停止境界

OBS-7Aの純粋診断とOBS-7Bの純粋候補生成・専用fixture・replayを実装した。
7Bは単一候補・複数候補・候補なし・比較不能を区別し、実データでも確認済み。
OBS-8では身体の実測相対yawによる限定変換を追加した。新しいHTTP endpoint、GUI、
RW2行動hook、支持数、追跡ID、canonical接続は追加しない。

OBS-8初版の実装条件は上記契約を参照。元観測の鮮度2秒、操作期限1.5秒、
最大45度・1回の水平回転、次の通常取得枠1回をfixture値として固定する。
専用Luantiで検証済み。一般環境やRW2生活中の自律Probeは未実装。

## 8. 継続Worldへ進む次の契約

[OBS-8B実装契約](../experiment-contracts/OBS_8B_continuous_world_probe_contract.md)を追加した。
現行8初版の有限Probeは固定し、通信待ちでも進む時計、生活intent優先の実行権限、
通常視覚枠の唯一の所有者、失効応答と配送ackの分離を専用fixtureで実装・検証した。
明示起動とfixture-distant-enabledを維持し、7B起動・自律注意・全感覚RW2統合は追加しない。
8Bは実Luanti 6ケースでA/Bの生活完了まで確認済み。[Evidence](../experiment-evidence/OBS_8B_continuous_world_probe_evidence.md)を参照。
この明示起動の調停で区切り、自律注意・全感覚生活統合・canonical接続は保留する。

## 9. 観測基盤v1の必要十分条件と終了地点

[OBS-9統合受入契約案](../experiment-contracts/OBS_9_observation_v1_completion_contract.md)をv1完了判定の入口とする。
全感覚生活＋限定Probe＋A/B＋継続World＋配送障害回復を同じ環境で検証し、固定した10項目が
全件通れば観測基盤v1 COMPLETEとして止める。現時点はOBS-8Bまで実装済み、OBS-9は未実施。
必要十分は後段研究に対する有限な受入条件であり、一般的な認識の完成ではない。
完了後は神経・解釈・Goal・Trajectoryへ戻り、追加感覚器や自律注意を完了条件へ後付けしない。

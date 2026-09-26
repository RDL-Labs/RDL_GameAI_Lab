# RDL_GameAI — 観測システム整備・導入計画

## 観測基盤v1の終了条件（2026-09-26）

OBS-8Bまでの個別・限定統合試験を基準に、最後の十分条件を
[OBS-9統合受入契約案](../experiment-contracts/OBS_9_observation_v1_completion_contract.md)へ固定した。
同一の継続WorldでA/Bの全感覚生活と限定Probeを併走し、10項目の受入が全件PASSしたら
観測基盤v1 COMPLETEとして止める。現在はOBS-9未実施、v1未完了。
以下の過去計画や将来の能力拡張を、v1の追加完了条件として扱わない。


**各系設計 / IMPLEMENTATION PLAN / DRAFT v0.2**  
**作成日：2026-09-26**  
**対象：RDL-Labs/RDL_GameAI_Lab**  
**確認済み基準：`a19fc2835dcc420ebb2a79a0b3daff7f94ca6e72`（RW2）**  
**更新元：`RDL_GameAI_Luanti_Distant_Observation_Implementation_Plan_v0.1.md`**  
**対象範囲：個体別観測条件、既存近景の設定化、遠景、最小聴覚、共通記録・表示**  
**初回作業：OBS-0〜OBS-2のみ。その完了報告で停止する。**  
**後続の早期導入：OBS-3遠景、OBS-4聴覚。嗅覚・感覚間照合・行動接続は保留。**

本稿はCodexへ渡す実装計画であり、新設する機能・数値・ファイル名を実装済みと扱わない。新しい名称と具体値はGameAI-localの提案であり、RDL Coreの定義でも実在動物の測定値でもない。

---

## 現在の区切り（2026-09-26）

OBS-0〜6Eは`23d4d2ad`で短いRW2生活試験用の観測基盤として一区切りとする。
以降の初回指示・工程表は導入時の計画履歴であり、実装成熟度はOBS-6の契約・Evidenceを参照する。
次は[感覚観測の解釈・利用への接続計画](RDL_GameAI_Sensory_Interpretation_Use_Plan.md)に従い、
OBS-7Aの純粋な比較適格性診断・replayまで実装した。OBS-7Bの候補生成とOBS-8は保留のままとする。

## 0. Codexへの着手指示

既存RW2のA/BそれぞれのFood取得・帰還・deposit・因果拘束付きresult admissionを維持し、**同じ観測処理を、個体ごとに異なる感覚条件で動かせる基盤**を作る。

全体の順序は次とする。

```text
OBS-0 基準・責務・契約を固定
  → OBS-1 個体別プロファイル＋共通frame＋隔離記録
  → OBS-2 既存近景をプロファイル参照へ移行
  → 初回停止／回帰と差分を報告

後続の別作業：
OBS-3 遠景の方向・粗い見え方
OBS-4 最小聴覚・短い音の受信窓
OBS-5 p5の個体別・感覚別read-only表示
OBS-6 統合回帰・有限予算・Evidenceの確定
  → 早期観測基盤の区切り

その後の別契約：
感覚間照合／目印の同定／方位・帰路利用／観測を使った行動
嗅覚／注意・疲労等の動的感覚変化／DNA・神経系
```

初回は、近景の既定値を変更せず、遠景や聴覚の実World機構を先行実装しない。観測基盤が通った後、遠景と聴覚を独立した小さな変更として追加する。**音は早期導入対象であり、視覚を完成させるまで待つ機能ではない。**

保全する原則：

```text
World内部の事実 ≠ その個体が取得した観測
観測条件の違い ≠ 解釈・報酬感度の違い
感覚能力の制限 ≠ サーバーの計算不足
観測記録 ≠ Experienceへの正式admission
観測の追加 ≠ H生成／T1起動／M_B更新／行動権限の追加
```

既存の近景はすでに行動・canonical側へ接続されているため、その接続を解除しない。**新設する遠景・聴覚・管理メタデータだけを、正式接続まで専用の観測経路へ隔離する。**

## 1. 改訂の目的と旧計画からの変更

### 1.1 目的

遠景だけのセンサー追加計画を、近景・遠景・聴覚を扱う観測基盤の整備計画へ拡張する。将来、人型NPC以外の身体や動物を同じRuntimeで動かせるよう、観測の条件を特定の個体型へ固定しない。

「感覚器の違いにより届く情報が変わること」と「同じ情報をどう解釈するか」を別経路にする。後者を本稿で実装するものではない。

### 1.2 改訂対応表

| 旧DOBS v0.1 | 本稿v0.2 |
|---|---|
| 遠景に特化した導入計画 | 観測基盤の下に遠景を配置する統合計画 |
| 近景12・遠景64等を初期sensor定数として提示 | 同じ値を既定プロファイルへ移し、個体単位で参照 |
| `observation.distant_features` | 共通の `observation.sensory_extension` 内の `vision_distant` frameへ統合 |
| 遠景専用store・GET | 個体別・感覚別の共通観測store・GET |
| 遠景の点的な取得時点 | 点取得と、聴覚の時間窓を別に表現 |
| 遠景は取得・表示まで | 同原則を維持し、最小聴覚も取得・表示まで |
| DOBS-0〜5を初回に実装 | 初回はOBS-0〜2。遠景と音は後続の独立単位 |
| 全sensorの大規模抽象化を避ける | 共通化は条件・識別・時間・予算・記録に限定。生成処理は感覚別 |
| 神経個体差を導入しない | 維持。固定sensor profileは神経系実装とは区別 |

旧計画を履歴として保持する。本稿を同じ実装領域の上位計画とし、旧計画と二重に独立した正本を作らない。旧DOBSの距離・FOV・遮蔽・未取得・情報非漏洩・再送・非介入テストは削らず、OBS-3と共通契約へ移す。

既にDOBSの実装が入っていた場合は、削除して作り直さず、実在するschema／endpointとの差を明記して移行する。本稿の新しい経路名を理由に、既存consumerを黙って壊さない。

## 2. 基準資料・現状・身分

### 2.1 確認済みの実装状態

基準commitはRW2の追加である。RW2は、同一Luanti World・Runtime内で専用Food/Baseを持つA/Bが独立に取得・帰還・deposit・結果受付を行う有限fixtureを対象とする。共有資源競合や複数個体のSleep／学習統合は、その完了範囲に含まれない。[R1][R2]

基準版の `/v1/observe` は同じpacketをpolicy、canonical capture、Experience登録、必要に応じSleep登録へ渡す。新しい観測欄を足すだけで「既存側が無視するはず」としてはいけない。[R3]

実装開始時に実際のHEAD・既存契約・未コミット変更を確認し、基準SHAとの差分をImplementation Notesに残す。基準SHAへの巻戻し、他作業の消去、Luanti本体の無断更新は行わない。

### 2.2 RDL資料の保持

| 資料 | 本稿で参照する責務 |
|---|---|
| BASE 正式版v2.3 | SILN・RIB、Bによる構造側／作用側の有限化、ξ残存 [T0-B] |
| SPEC 正式版v2.4 | `Section_B`の位置・時間・方向・操作解像度、同一の更新前M_BによるF/F'比較 [T0-S] |
| T1総論・展開・検査・再構成 | 取得、展開、検査、選別、再構成の身分差。sensor実装は各系設計 [T1] |
| TD共有語彙・自然言語翻訳 | RIB_Bと解釈F、意味・価値、異なるBと異なるM_Bの区別 [TD-D] |
| TDのρ・時間・空間 | 範囲と解像度、点と時間幅、位置・方向と到達可能性の区別 [TD-R][TD-T][TD-S] |

資料の版を勝手に統一しない。SPEC v2.4ではρをStandard Modelに導入している一方、添付TD詳細文書には昇格前の暫定記述が残る。ρの現在の仕様上の身分はSPEC v2.4を参照し、TDは区別の詳細説明に用いる。

```text
SensorProfile：具体的な切り出し条件の一部を保持するGameAI-local設定
SensorProfile ≠ B全体
SensorFrame ≠ RIB群全体
SensorFrame ≠ canonical RIB_Bとしてのadmission済みデータ
sensor resolution ≠ 誤差の重み付け／reward threshold
sensor detector threshold ≠ θ／θ_eff
```

観測対象を出力に載せるための幾何・閾値検査を、T1のretain/reject/deferと同一視しない。本稿で学習・行動接続を保留するのは初期導入の制限であり、Core上の軽量T1や通常運転での更新を禁止する規則ではない。[T1]

## 3. 成功条件と非目標

### 3.1 早期導入全体の成功条件

同じWorldから、各個体の感覚条件と姿勢に対応した有限な観測を作り、取得時点と出典を保って記録・表示できること。新設チャンネルの有無だけでは既存の生活・学習・canonical処理を変えないこと。

近景プロファイルを意図的に変えた実験では入力と行動が変わり得る。それは期待される介入であり、同一入力での非介入試験とは区別する。

### 3.2 非目標

一般的な画像認識、山全体の自動抽出、完成した動物生態、種別の実測感覚値、発話理解、音源の恒久同定、感覚融合、SLAM、絶対方位・帰路の推定、自由探索Goal、L10行動権限を追加しない。

神経系、報酬閾値、注意、疲労、DNA、発達を実装しない。匂いの痕跡場、風・拡散、流体計算も早期導入範囲外。これらへ接続可能な境界は残すが、未使用の複雑なframeworkを先に作らない。

## 4. 全体構成と所有者

```text
Luanti World／実際に解決されたWorldイベント
  ＋ 個体に割り当てられた固定SensorProfile
  ＋ 取得時の身体位置・感覚器位置・向き
  ＋ 感覚別の伝達・遮蔽・検出モデル
  ↓
[共通部分] 条件解決・時計・識別・有限予算
  ├─ vision_local   ：既存の近距離構造化観測
  ├─ vision_distant ：方向と粗い外観
  └─ audition       ：時間窓内に届いた音の特徴
  ↓
個体別SensorFrame
  ↓
Runtime入口で隔離
  ├─ 既存packet → 従来のpolicy／Experience／canonical／Sleep
  └─ 新規frame → 有限観測store → read-only GET → p5
```

| 所有者 | 保持するもの／持たせないもの |
|---|---|
| Luanti World | 物体、材質、位置、身体、Worldイベント、音の発生。NPCの危険判断は保持しない |
| sensor adapter | プロファイル、有限な検査、取得結果。目印・敵・報酬等の認定をしない |
| Runtime観測store | 検証済みframe、所有者、時刻、受領状況。意味を追加しない |
| 既存Runtime意味論 | 既存の生活・履歴・canonical経路。新規チャンネルは初期には入力しない |
| p5 | 公開された観測と鮮度の表示。欠けた情報の補完・行動命令をしない |
| 試験harness | 配置、既知の正解、raw World出典、scripted回転。NPC入力とは分離 |

同じコードを使っても、視覚・聴覚・嗅覚を「共通半径内の物体一覧」へ潰さない。取得時点、伝達、検出可能な特徴が異なるため、共通envelopeに感覚別payloadを載せる。

## 5. 個体別観測条件

### 5.1 三つを分離する

```text
SensorProfile        ：個体へ割り当てる静的な感覚条件
ObserverPoseSnapshot ：その取得時点の位置・姿勢・感覚器の局所座標系
ObservationBudget    ：実験／実行環境の資源上限
```

種・身体型のpresetから個体用profileを構成してよいが、初期には種名で処理を分岐しない。異なる値を持つ同じ型として扱う。実在動物名を使った場合も、生物学的妥当性を検証済みとは書かない。

profileは内容とrevisionを固定する。実行中に書き換えて過去frameを別条件の観測へ変えない。初期のprofile変更はrun開始時のみとし、動的変更は別契約にする。

### 5.2 初期profile例

以下はschema設計例であり、値は実験用である。

```json
{
  "profile_id": "fixture-sensor-default",
  "profile_revision": 1,
  "vision_local": {
    "enabled": true,
    "mode": "legacy_radius_v1",
    "origin": "body_center",
    "radius": 12.0,
    "fov_enabled": false,
    "occlusion_enabled": false
  },
  "vision_distant": {
    "enabled": false,
    "mode": "sampled_surface_v0",
    "eye_offset": [0.0, 0.5, 0.0],
    "range_min_exclusive": 12.0,
    "range_max_inclusive": 64.0,
    "horizontal_fov_deg": 90.0,
    "vertical_fov_deg": 60.0,
    "angle_bin_deg": 5.0,
    "sample_every_world_ticks": 4
  },
  "audition": {
    "enabled": false,
    "mode": "direct_band_energy_v0",
    "ear_offset": [0.0, 0.5, 0.0],
    "radius": 32.0,
    "band_gains": [1.0, 1.0, 1.0],
    "detection_floor": 0.05,
    "mask_ratio": 2.0,
    "direction_bin_deg": 30.0,
    "report_every_world_ticks": 4
  }
}
```

`agent_id → profile_id + revision`の対応は別registryで保持する。未知profileの要求や上限外の値を黙って既定値へfallbackしない。既存fixtureだけは明示的に既定profileへ登録する。

眼／耳offsetは取得点の幾何であり、身体を実際に移動する設定ではない。近景をbody centerで取得していた基準動作はそのまま残す。近景まで眼基準へ変える変更は、別の観測条件変更として試験する。

### 5.3 共有と個体差

A/Bが同じprofileを参照する場合、profile自体は読み取り専用で共有してよい。取得結果、sample sequence、姿勢revision、音の受信待ち、通信待ち状態は個体別に保持する。

異なるprofileの試験は、例えば詳細半径12と8、遠景FOV90度と120度、聴覚gainの異なる組合せで行う。これを「慎重型」「研究型」といった人格へ直結させない。

## 6. 感覚能力と計算予算を混同しない

能力上のradius、方向解像度、検出閾値と、実装上の候補数・ray数・buffer容量を別に持つ。

```text
小さい音が検出閾値未満
→ 採用した感覚モデルでは検出されない

音処理の予算を使い切った
→ その窓の取得が不完了
→ 「無音」へ変換しない
```

最大radius等の実装上限を超えるprofileは起動時に拒否する。こっそりclampして別の感覚能力にしない。運転中の予算不足はprofileを変えず、取得coverageと診断側へ記録する。

身体のsensory limitと計算資源の違いを保持するため、負荷試験では同じprofileのままbudgetのみを変更する。予算を下げた結果を視力低下や聴力低下として学習させない。

---
## 7. 共通frame・時間・取得状態

### 7.1 共通化する項目

| 項目 | 意味 |
|---|---|
| run／world epoch | 再起動・WorldリセットをまたいだID再利用を防ぐ |
| agent・sensor・channel | 誰の、どの感覚器による取得か |
| profile ID／revision | 取得条件。後から別版へ置換しない |
| sensor model revision | 遮蔽・減衰・量子化等の実装契約の版 |
| sample sequence／frame ID | 取得の識別。対象の恒久同一性は表さない |
| capture window | 点取得か時間窓か、いつ取得した情報か |
| observer frame ref | 取得時の感覚器局所座標系への参照。World座標ではない |
| status／coverage | 取得できたか、有限計画に対して不完了があるか |
| payload | 感覚ごとに異なる観測値 |

近景・遠景・聴覚の最終取得を並べても、同時刻の完全なWorld snapshotを再構成したとは扱わない。

### 7.2 時刻の取り決め

既存RW2のWorld tickを変更しない。短い音を扱うため、adapterに単調なsimulation clockを追加し、整数の`sim_time_us`と`clock_id`を保持する。これは観測の順序・時間幅用であり、一般的な生活時間・生物学的な体内時計の実装ではない。

実機ではsimulationのstep時間から進め、テストでは同じ時計を注入可能にする。壁時計、HTTP完了時刻、p5の`Date.now()`を取得時刻として代用しない。小数stepを整数へ丸める場合は端数を保持し、丸めの累積で時計が止まらないようにする。

- 視覚：点取得。`start_us == end_us`。
- 聴覚：原則 `(start_us, end_us]` の受信窓。境界上の音を二重計上しない。
- HTTP到着：別の受領時点。遅れて届いても取得時点は書き換えない。
- 姿勢変化：個体の`observer_frame_ref`を更新する。過去の角度を現在姿勢の角度として表示しない。

音の方向を取得した時点の姿勢と、窓の終了時の姿勢は異なり得る。聴覚payload内の各検出にも取得時のframe refを持たせ、異なる姿勢の方向を同じ角度セルへ混ぜない。

### 7.3 取得状態

| 状況 | 記録方法 |
|---|---|
| 機能無効／その周期では未取得 | 新frameなし。管理側にdisabled／not dueを保持 |
| 有限計画を調べて検出あり | `SAMPLED`＋観測配列 |
| 有限計画を調べたが検出なし | `SAMPLED`＋空配列 |
| 調べた範囲の一部が不明・予算不足 | `SAMPLED`＋`PARTIAL`。確実に取得した内容だけ |
| 有効な取得が成立しない | `UNAVAILABLE`＋`UNAVAILABLE`＋空payload配列 |
| 前のframeを画面に残している | 同じframe IDと古い取得時点を表示。新規取得にしない |

`COMPLETE_WITHIN_PLAN`は、設定した有限registry・受信モデル・検査計画を処理したという意味に限る。世界の全対象を取得したことや、その場に何も存在しないことは意味しない。

出力上限による切詰め、受信bufferの欠落、または検査未完了があれば、対象を特定しない`PARTIAL`とする。`output_limited=true`のframeを完全取得として表示しない。

通常frameへは、未検査対象のID、壁の裏の対象名、聞こえなかった音源の件数を出さない。coverage不足は一般的な状態で表し、対象別の除外理由や正確な省略数はharness診断へ分離する。

## 8. Packet契約と旧DOBS形式の移行

### 8.1 新しいenvelope

新設する専用欄は **`observation.sensory_extension`** とする。旧計画の`distant_features`をこの中へ統合し、遠景と聴覚で別の平行storeを増殖させない。

以下は外側の既存packetに付加するextensionの例である。

```json
{
  "schema_version": "rdl-sensory-extension-v1",
  "run_id": "run-001",
  "world_epoch": 1,
  "agent_id": "npc_a",
  "delivery_observation_id": "luanti-multi-000020-npc_a",
  "delivery_world_tick": 20,
  "delivery_time_us": 5000000,
  "frames": [
    {
      "frame_id": "run-001:1:npc_a:eye:vision_distant:5",
      "agent_id": "npc_a",
      "sensor_id": "eye",
      "channel": "vision_distant",
      "profile_id": "fixture-distant-enabled",
      "profile_revision": 1,
      "sensor_model_revision": "sampled-surface-v0.2",
      "sample_seq": 5,
      "clock_id": "world-sim-v1",
      "capture_window": {
        "kind": "instant",
        "start_us": 5000000,
        "end_us": 5000000
      },
      "sampled_world_tick": 20,
      "observer_frame_ref": "npc_a:eye-pose:2",
      "status": "SAMPLED",
      "coverage": "COMPLETE_WITHIN_PLAN",
      "output_limited": false,
      "payload": {
        "features": [
          {
            "feature_id": "f0",
            "azimuth_interval_deg": [25, 30],
            "elevation_interval_deg": [0, 5],
            "angular_width_band": "small",
            "angular_height_band": "medium",
            "color_band": "dark_gray"
          }
        ]
      }
    }
  ]
}
```

このframe例は、既定profileを複製して遠景だけを明示有効化した`fixture-distant-enabled`をrun開始時に登録した場合である。既定offのprofileのままframeを発行してはならない。

frame内の`feature_id`はframe内局所IDである。永続World IDのハッシュ、mesh ID、texture名、音源IDを入れない。同じ物を次に見ても同じIDになる保証を与えない。感覚間で共通のWorld由来キーも付けない。

### 8.2 配送と再送

`delivery_observation_id`は、そのextensionを載せた外側packetの`observation_id`と一致させる。`delivery_world_tick`は外側tickと一致させ、frameの取得終了時刻が`delivery_time_us`を超えないことも検査する。外側agent、extension agent、各frame agentは一致必須。run／epoch／profileは起動時に登録したものと照合する。各agentに許可されたprofile版とchannel有効状態も検証し、任意の自己申告profileを受け付けない。

不変なのは取得済みframe本体である。通信遅延や再送時には、古いframeを新しいlegacy packetのextensionとして載せてもよい。その場合、配送IDだけを新しい外側packetへ合わせ、frameのID・取得時刻・内容を変更しない。

旧DOBSの「取得tickと配送packet tickは常に同じ」という前提を、時間窓と再送を扱う本稿では採用しない。初回受信の未来時刻や別epochは拒否し、過去frameは後述の順序規則に従う。音の配送遅延から、音源までの距離を計算することもしない。

再送のために過去の`/v1/observe`要求全体を繰り返して、既存policyや履歴の二重処理を誘発しない。配送情報とframe本体のハッシュを分け、配送先packetが変わったことだけで同一frameを内容改変と誤判定しない。

### 8.3 適用範囲が違うpayload

`vision_local`だけは既存の近景schemaを引き継ぐ。既存Food/Base IDやfixtureカテゴリは、既に使用されている限定的な既知情報として保持する。これを純粋な無意味の画素観測と呼ばない。

新設する`vision_distant`と`audition`は厳格なallowlistとし、正確なWorld座標・距離・恒久対象ID・価値・敵味方・行動指示を拒否する。共通envelopeだからといって、近景の既知IDを遠景・音へ流用しない。

初回の近景frameを保存する場合は、実際に既存packetへ採用した有限一覧だけをコピーする。Worldから別途広い一覧を取り直さない。新しいIDを生成して既存近景のIDを置き換えることもしない。

### 8.4 Schema検証

列挙値、有限数、非負sequence、時間窓、個体所有、profile版、配列件数、文字列長、extension bytesを検証する。空配列は`[]`とし、`null`を黙って空観測へ直さない。

禁止語検索だけに頼らず、schema外の属性を拒否する。不正な値を含むframeは検証完了前に一部保存しない。frameの同一性比較は規定した正規化JSONに基づき、任意の文字列表現差で再送が不一致にならないようにする。

旧`distant_features`が実装済みなら、移行期間に専用変換を一つ置く。二重入力時は同一frameを二回保存しない。非対応の旧拡張も既存意味論consumerへ流さず、明示拒否する。

## 9. 近景：既存動作を壊さない設定化

### 9.1 最初に行う変更

Luantiの近距離判定が、共通の固定値12ではなく、対象agentに割り当てた`vision_local.radius`を参照するようにする。

既定profileでは、body中心、半径12、従来のFood/Base割当、対象の順序、body/life_context、到達判定を保持する。既存の`perception_rule`や観測ID生成を、単なる設定化のために変更しない。

**観測距離と手が届く距離は別**であり、視力profileを変えただけでpickup reachや移動量まで変更しない。

### 9.2 保留する近景変更

近景をいきなりFOV／遮蔽依存へ切り替えない。近景のモデル名は`legacy_radius_v1`と明示し、遠景との精度・方向性の違いを隠さない。

将来`fov_occlusion_v1`等へ移す場合、別mode・別revisionにする。たとえば近景body中心と遠景eye基準では、境界の空間形状が完全一致するとは限らない。rangeの隙間・重なりは契約として扱い、自動的な同一対象の統合で埋めない。

### 9.3 初回の個体差試験

同じ対象を距離10に置き、Aの近景半径12、Bの近景半径8で観測差が出ることを確認する。比較時は位置・向き・他の条件を同じにし、profileだけを変える試験も用意する。

このprofile差をRW2本番経路へ同時に入れ、帰還失敗を新規sensorの不具合と混同しない。既定profileの回帰試験と、非既定profileの介入試験は分ける。

## 10. 遠景：旧DOBSの仕様を保持して統合

### 10.1 役割

遠景は、方向・粗い見かけ・観測時点を渡す。正確な距離、World座標、対象名、帰路、操作対象IDを渡さない。

```text
見える ≠ 同じ対象と分かる
同じ対象らしい ≠ 絶対方位が分かる
方位の手掛かり ≠ 現在地・到達可能性・帰路
```

初期は外観が異なる不透明固定構造物2つを使う。柱と板などでよく、山の認識器を実装しない。

### 10.2 幾何と粒度

取得時の眼位置・yawから校正した前方／右／上の局所基底を作り、相対方向を計算する。v0ではpitchを0に固定する。左右は実機で校正し、Worldの絶対yawをNPCへ送らない。[L1]

```text
d = sample_point - eye_position
azimuth   = atan2(dot(d, right), dot(d, forward))
elevation = atan2(dot(d, up), hypot(dot(d, forward), dot(d, right)))
```

距離とFOVはraw値で判定し、採用後に角度を区間化する。基準profileは5度幅。左右・±180度の周期境界・ゼロ長・非有限値・境界上の包含をテストする。

角度幅・高さは、実際に可視になったサンプルの角度範囲から作る。帯は初期提案として`small <5度`、`medium 5〜15度未満`、`large >=15度`。サンプル不足の次元は`unknown`。隠れた全体形から幅を補完しない。

### 10.3 遮蔽と有限proxy

World内の有限registryから候補を取得してよいが、登録だけで可視にしない。構造物の実際の可視材質・幾何に対応するサンプルを、対象ごと最大5本検査する。

v0は空気と不透明full-cube材質に限定し、上限付きvoxel走査で眼からサンプルまでを検査する。眼から12以内の壁も遠景を遮る。未知材質、未読み込み、`nil`、`ignore`は透明扱いせず取得不完了とする。Luanti APIの未読み込みの扱いは[L1]を参照。

Raycastを使う実装へ変更する場合は、selection box基準と読み込み・回転等の制約を確認し、DDAと同じ実装であると扱わない。[L2]

センサーから無制限のmap生成・forceloadを起動しない。fixture準備で有限領域だけを用意し、解除処理を持たせる。

この方式では、fixture registryが対象候補のまとまりをWorld側で既知としている。**一般画像から物体を分割する課題は未実装**であり、恒久IDを送らないだけで完全な視覚認識になったと主張しない。

### 10.4 出力と非採用対象

出力順は観測した角度・外観等の規定順とする。World IDで順序を固定して追跡キーを漏らさない。同じ特徴の物が二つあれば区別が未確定のまま残ってよい。

隠れた物の名称や「対象Xが遮蔽中」という情報を返さない。透明物、動的Mob遮蔽、昼夜、天候、一般地形は後続へ回す。

---
## 11. 聴覚：早期に入れる第二の感覚

### 11.1 目的と範囲

見えていない方向で起きた出来事からも、有限な特徴を受け取れるようにする。ただし音を聞いた直後に「獣」「危険」「他個体の接近」と認定しない。

初期は波形・音声認識を使わない。短い衝撃音、移動結果に対応する簡易音、固定した帯域の継続音など、少数の合成イベントを使う。実際の物理音響の再現ではなく、**発生→伝達→検出の責務を分けた検証用モデル**とする。

### 11.2 発生源をWorld側に置く

```text
成功したWorld上の移動／接触／発声等、または明示fixture操作
  → WorldSoundEvent（World内部）
  ├─ プレイヤーへの音再生（任意）
  └─ NPCごとの受信・検出処理
       → HearingDetection（個体側の観測）
```

WorldSoundEventはWorld内部の位置、発生時点、継続時間、有限帯域エネルギーを保持してよい。NPCへはそれを丸ごと転送しない。再生assetのファイル名、音声文字列、音源entity ID、意図した行動名は通常観測へ出さない。

`core.sound_play()`はLuantiの音再生APIであり、NPCへの観測契約とは別に扱う。[L1] 共通のWorldイベントから両方を派生させ、プレイヤー用音量やカメラ位置がNPCの聴覚を変えないようにする。headlessでもNPCの聴覚試験が通る構成にする。

既存の全mod・全音を自動捕捉できるとは主張しない。初期は自作fixtureの明示emit関数から発生した音だけを対象とする。既存actionの要求だけでは音を発生させず、結果の成立後にemitする。失敗した移動要求に「成功した足音」を付けない。

既存fixtureの座標移動から音を作る場合、それは簡易Worldモデル上のイベントであって、接地や歩容の物理的再現ではないことを記録する。

### 11.3 v0伝達モデル

モデル名を`direct_band_energy_v0`として固定する。初期は伝播遅延0、直接経路のみ。反射、回折、残響、ドップラー、両耳波形、リアルな音源定位を扱わない。

提案する有限な計算例：

```text
band k ∈ {low, mid, high}
received_k = emitted_k × A(distance) × T_k(path)
A(distance) = 1 / (1 + (distance / d0)^2)
perceived_k = gain_k(profile) × received_k
```

初期fixtureの具体値は、`d0=4`、各帯域のemit energyを`[0,1]`、profile gainを`[0,4]`、各帯域noise floorを`0.01`とする。空気の透過係数は1、試験壁は通過したvoxelごとに0.5を掛ける簡易方式とし、厚さに依存することを明記する。これらと帯域区分はfixture設定・モデル版に含め、単位を無次元の検証用energyに固定する。音圧dBや生物学的聴力値と呼ばない。

検出は、同じ受信セルへ届いたenergyを合算してから、profileのgain、検出閾値、noise floorに対する規定比を適用して行う。弱い源を個別に捨てた後で残りだけを合算しない。閾値は例示profileの0.05、noise比は2を初期値とする。gain適用後の値を帯化する直前に`[0,1]`へ飽和させ、検出閾値ちょうどを含める。強さの帯は初期提案として`weak <0.2`、`medium 0.2〜0.6未満`、`strong >=0.6`とする。最大帯域の同値を含む支配帯域の判定は、同値なら`mixed`とし、任意の音源名で決めない。

遮蔽物には、視覚の不透明判定とは別の帯域別透過係数を持たせる。既知の不透明壁でも、音は減衰して届き得るfixtureにする。視覚の可視一覧を聴覚の候補一覧として使わない。

音の経路も有限voxel走査で検査する。未対応材質・未取得node・予算終了では、その経路の伝達を勝手に0または1へ確定しない。確定可能な観測だけを残し、受信窓をPARTIALにする。

### 11.4 短い音を取得周期の間で失わない

HTTP送信や遠景のsamplingとは独立して、Worldで音が発生した時点の観測者位置・耳の向きで伝達を評価し、同じ受信セルへ蓄積する。v0の遅延0モデルでは発生時点を受信時点とする。

```text
音が発生
→ その時点の耳位置・姿勢で有限な伝達計算
→ 個体別の短期受信セルへenergyを蓄積
→ セル確定時に混合・profile検出閾値の適用
→ 次の聴覚窓の確定時にframe化
→ HTTP配送
```

次の視覚更新時にまだ音源が存在するかどうかで、過去の受信を消さない。反対に、後で音源へ近づいたことを理由に、以前は届かなかった音を過去へ遡って聞かせない。

bufferは感覚入力の短期保持であり、長期Experienceや記憶学習ではない。音の途中で姿勢が変われば、検出ごとに取得時の局所座標系を保存する。窓を閉じる時点の姿勢で全方向を再計算しない。

起動前の音を後から取得しない。イベントの時間順、同時刻の順序、窓端の包含、継続音の有限分割を契約化する。継続音も無制限の毎stepイベントにせず、長さと生成レートを上限管理する。

### 11.5 音源分離を無料で与えない

Worldイベント一件につきNPC観測一件を必ず返す設計は避ける。同じ粗い方向・受信時間帯・姿勢基準で重なった音は、有限なenergy混合として一つの検出へまとめられるようにする。

最初の試験では単音を中心に使うが、少なくとも同一セルの二音を混合する試験を追加する。検出件数を音源の実数とみなさず、発生源を特定できたかのようなsource confidenceは付けない。

World上の同一音がA/Bへ届く場合も、通常の観測IDは各個体に別々に発行する。共通World event IDを入力へ渡して、感覚間・個体間の同定を解決済みにしない。完全な対応はharness用provenanceに残す。

### 11.6 聴覚payload例

次は共通frame内のpayload例。方向は当該検出時の耳基準であり、正確なWorld方位・位置ではない。

```json
{
  "detections": [
    {
      "detection_id": "d0",
      "received_interval_us": [5010000, 5060000],
      "observer_frame_ref": "npc_a:ear-pose:2",
      "azimuth_interval_deg": [-120, -90],
      "elevation_band": "unknown",
      "received_strength_band": "weak",
      "dominant_band": "low",
      "temporal_form": "brief"
    }
  ]
}
```

`low / mid / high / mixed / unknown`等の有限な特徴語を使用する。「足音」「獣」「味方」はこの段階の出力語彙に入れない。方向を取得できないprofileでは`azimuth_interval_deg`を出さず、schemaで明示したunknown状態を使う。方向unknownを正面0度に置換しない。

## 12. Runtime入口・保存・配送の分離

### 12.1 既存の全consumerへ同じlegacy packetを渡す

```text
受信packet
  → 非破壊で既知のsensor拡張を分離
       ├─ legacy_packet
       │    → 従来policy
       │    → canonical capture
       │    → Experience decision registration
       │    → Sleep registration
       └─ sensory_extension
            → strict validation
            → agent/channel別store
            → read-only snapshot／受領情報
```

基準実装が同じpacketを複数経路へ渡すため、この分岐を入口に一度だけ設ける。[R3] 呼出先ごとに異なる部分コピーを作って、一部のconsumerへsensor情報が残る構造にしない。

profileメタデータ、音、遠景、coverageを既存の`recent_events`へ混ぜない。遠景や音の件数を従来の可視対象数へ加算しない。新規frameの検証失敗をcanonicalの不整合Eとして扱わない。

### 12.2 機能無効と不正拡張

提案するRuntimeフラグは`--sensory-observation`、Luanti側の有効化は`rdl_sensory_observation`。どちらも既定off。近景profileの互換設定化は、新規チャンネルを有効にしなくても利用できる。

Runtime機能offでも、既知のsensor拡張はlegacy consumerへ流さない。新規frameだけが不正なら、sensor側で拒否し、正常なlegacy packetのFood行動は維持する。legacy packet自体の不正は従来どおり拒否する。

新しいreceiptを既存action responseに混ぜない。受領状態は専用GETから取得する。既存actionの処理をsensor receipt待ちにしない。

本文の隔離はアプリ内部の権限分離であり、ネットワーク認証の保証ではない。接続は従来どおりローカルを前提とし、任意の外部World／第三者クライアントへ公開しない。

### 12.3 有限storeと冪等性

保存キーは`run / epoch / agent / channel / sensor / sample_seq`とframe IDで固定する。同じ眼を使う近景と遠景でも、channelを含めてsequenceを分離する。profileやsensor model revisionもframe内容として保持する。

- 既登録の同一frame・同一内容は再送として受理し、保存件数を増やさない。
- 同一frame IDで内容が異なる場合は拒否する。
- 未登録の古いsequenceは初期v0では拒否し、latestを巻き戻さない。
- 他個体・別run・別epoch・未知profileは拒否する。
- frameは検証・容量確認後に一括保存する。一部だけ残さない。

全frameを一律一つの最新値へまとめず、個体×channelごとにlatestを保持する。Aの保存上限到達を理由にBの枠を消費・削除しない。

初期storeは各個体・各チャンネル64frameで明示拒否型とする。容量到達後に古い履歴を暗黙削除しない。latestの意味を保つため、保存されなかったframeを最新保存済みとして表示しない。長期保存・圧縮・永続化は別契約へ回す。

### 12.4 短期bufferと再送待ち

Luanti側の音受信bufferと未送信frame bufferは有限とする。新しい観測を取得する処理と、HTTPで送れるかどうかは分離する。

未送信frameは一つの送信周期につき最大1回再送し、規定したTTLまたは回数上限で打ち切る。完全なframe本体を保持して再送し、古い音を新しい受信として増やさない。

受信buffer溢れ、未送信buffer溢れ、TTL終了は区別して診断記録に残す。音の受信範囲の欠落は次の受信frameのcoverageにも反映するが、欠けた音源の名前・位置は公開しない。

有限の受領履歴が一杯で確認不能の場合は、受領済みと推測しない。再送がRuntimeの保存件数・行動件数を増やさないことを試験する。

## 13. 初期予算と計算負荷

以下は実験用の提案上限。能力profileとは別のObservationBudgetに置く。固定の実行時間を保証する数値ではない。

| 資源 | 初期上限 |
|---|---|
| 能動観測個体 | 2体。境界試験markerは含めない |
| 登録profile | 8件 |
| 新規channel | 近景互換・遠景・聴覚の3種類まで |
| 遠景registry | 8対象、最初の配置は2対象 |
| 遠景の出力 | 個体ごと4特徴／取得 |
| 遠景のray | 個体ごと40本／取得 |
| rayのvoxel訪問 | 128回／ray。範囲を先に制限 |
| 聴覚の源イベント受付 | 32件／既存World tick。受付超過は診断 |
| 聴覚の経路検査 | 個体ごと8経路／既存World tick |
| 聴覚の受信buffer | 個体ごと32受信セル（閾値判定前を含む） |
| 聴覚frameの出力 | 最大8検出セル／窓 |
| 音の時間量子化 | 初期50ms。Worldイベントの継続時間と別 |
| 追加チャンネル全体のray上限 | 2体合計96本／既存World tick |
| 追加チャンネルのnode訪問上限 | 2体合計12,288回／既存World tick |
| frame未送信buffer | 個体ごと8frame |
| 再送 | 最大3回、または32 World tickのTTLまで |
| extension | 最大16 KiB／packet、最大4frame |
| 共通store | 最大2個体×3channel×64frame |
| ID長 | 最大128文字。公開文字列は列挙または上限付き |
| p5取得 | 既存のLive GET周期を利用 |

遠景のみのframeの大きさは旧計画の8 KiBを目安とし、16 KiBへ拡張したenvelopeを使って無制限にpayloadを増やさない。

上限に達した際、全対象を先に列挙してから出力だけ切り詰める方式を避ける。有限fixture registry、サンプル数、経路長、Worldイベント生成数を入口で管理する。実機の近景検索も有限fixture外の全Worldを走査する保証には拡大しない。

合計上限は各sensorの上限に加えて検査する。片方の個体の処理が残りの全予算を取り続けないよう、初期2体には固定の個体別枠を割り当てる。動的な一般schedulerは作らない。

未実行分を翌tickに無制限に追い付かせない。センサー処理時間、World処理時間、HTTP待ち、保存件数、overflowを分けて計測する。初期予算内であっても実機が重い場合は、結果を記録してbudget／profileのどちらを変更したか明示する。

## 14. p5・読み取り専用endpoint

新設先の提案：

```text
GET /v1/sensory-observation-snapshot
```

既存GET-only proxyの許可経路へ追加する。sensor profile書換、視線操作、音のemit、review、cutover等のPOSTをp5に追加しない。

選択個体ごとに、profile版、各channelの有効状態、最終取得窓、frame ID、coverage、取得姿勢ref、受領／保存状態を表示する。遠景は角度区間・粗い外観、聴覚は受信区間・粗い方向・強さを表示する。

未取得、検出なし、不完了、古いframe、受領失敗、保存上限を区別する。他個体の最新値でfallbackしない。現在のWorld時刻が公開されていなければ、p5壁時計から架空のsimulation ageを作らない。

方向は取得当時の局所座標系で表示する。古い音を現在の正面方向へ勝手に回転させず、「取得姿勢の基準」と明示する。World位置が非公開である条件を維持し、地図や音源座標へ復元しない。

既存Luanti Life Traceとcanonical Inspectorは保持する。sensor frameをExperience件数やT1材料数へ加算しない。UIの追加は小さな観測パネルに限定し、Workbench全体の作り直しをしない。

## 15. 非介入・個体差・負荷の試験を分ける

### 15.1 既定profileの互換性

旧固定値を既定profileへ移した場合、同じWorld条件で従来近景packetの既存部分が等しいことを確認する。型、並び順、ID、body/life_context、perception_ruleも検査する。

### 15.2 新規チャンネルの非介入

同じlegacy packet列をRuntimeへ流し、新規extensionだけを付け替える。

```text
同じlegacy packet列
＋ 遠景なし／遠景あり／音あり／不正extension／store満杯
→ 既存action、Goal/Trajectory、result admission、Experience、
   canonical E/H/θ/M_delta、T1/model/archive/cutoverが同一
```

比較するのは実際に同じ列を処理した出力である。別々の未使用sidecarが空のままであることを示すだけの試験では不可。

### 15.3 観測条件への意図的介入

profile、姿勢、遮蔽を変えた試験では観測が変わることを期待する。近景変更で行動が変わった場合は、観測条件の介入結果として扱う。これは新規extensionからの権限漏れとは別問題である。

### 15.4 実機の時間差

同一fixtureでも、追加処理によりHTTP完了の実時間や個体間の到着順は変わり得る。実機試験では個体ごとの行動順・対象・結果・出典を比較し、完全に同じwall-clock順序を要求しない。意味論一致は固定packet replayと組み合わせる。

## 16. 実装フェーズ・停止条件

| Phase | 内容 | 完了に必要な証拠 |
|---|---|---|
| OBS-0 | 現HEAD確認、旧DOBS対応、schema・責務・予算の固定 | 基準回帰・不一致・新規提案の区別 |
| OBS-1 | 固定profile registry、clock/frame型、入口隔離、store/GET | schema、所有、時刻、冪等、容量、不正拡張の隔離 |
| OBS-2 | 近景を個体profile参照へ移行 | 既定profileのRW2互換、異なる半径による観測差 |
| OBS-3 | 遠景v0、有限固定物、幾何・遮蔽・旧DOBS回帰 | 実Luantiの方向・境界・部分観測・未取得 |
| OBS-4 | World音イベント、有限伝達、個体別検出・時間窓 | 短音、壁越し減衰、profile差、重複・overflow |
| OBS-5 | p5の共通sensor表示 | 個体・channel・時刻・欠落状態の一貫した表示 |
| OBS-6 | RW2と遠景・音の併走、負荷・非介入の統合検査 | 機能別Evidence、実機／replayの区別、早期範囲の完了 |
| OBS-7 | 感覚内／感覚間の照合候補 | **DEFERRED。恒久同定・自動融合なし** |
| OBS-8 | 方位・視線・帰還・行動への限定利用 | **DEFERRED。別の行動契約が必要** |
| OLF-0 | 嗅覚要件と境界の文書化 | **将来用。runtime実装なし** |
| OLF-1 | 有限な痕跡嗅覚fixture | **DEFERRED。別途許可後** |

推奨する作業単位：

```text
初回：OBS-0〜2 → 停止
第二単位：OBS-3 → 停止
第三単位：OBS-4 → 停止
第四単位：OBS-5〜6 → 早期観測基盤を締める
```

OBS-4はOBS-1〜2の基盤に依存するが、一般的な視覚認識の完成には依存しない。OBS-3が画像認識や一般地形へ拡大しそうならそこで止め、最小聴覚へ進める。

## 17. Acceptance matrix

| ID | 条件 | 必須結果 |
|---|---|---|
| C01 | 共通基盤off、旧起動方法 | 既存RW2・L0–L2・L3・L7の契約を維持 |
| C02 | 全個体に既定profile | 旧近景packetの既存部分と出力が一致 |
| C03 | 同じ姿勢、近景半径12／8、距離10の対象 | 観測差だけが条件に応じて発生 |
| C04 | 未知profile、非有限値、上限外radius | 起動／登録拒否。無言のclampなし |
| C05 | 同じprofileをA/Bで共有 | 結果、pose、sequence、bufferは非共有 |
| C06 | 未取得／空検出／PARTIAL／UNAVAILABLE | 別状態。全Worldの不在へ変換しない |
| C07 | 個体・run・epochの不一致 | frame拒否。既存／他個体storeの部分更新なし |
| C08 | 完全再送／内容改変再送 | 冪等受理／拒否 |
| C09 | 過去の新規sequence／未来取得時刻 | 拒否。latestが巻き戻らない |
| C10 | 新規sensorだけ不正／機能off | 拡張が既存consumerへ漏れず、正常legacy処理は維持 |
| C11 | 一方のstore満杯 | 明示拒否。他個体の枠・値は変わらない |
| C12 | 同一legacy列、extensionのみ変化 | action・life・Experience・canonical・T1全経路が同じ |
| V01 | 回転・横移動・A/B別姿勢 | 遠景方向が実配置どおりに変化 |
| V02 | 距離下限、直後、上限、直後 | raw値でprofileの包含条件を守る |
| V03 | FOVの内側・境界・外側 | 量子化前の採否、左右・周期境界が正しい |
| V04 | 近距離の不透明壁 | 遠景を遮る。隠れた対象名を返さない |
| V05 | 一部サンプルのみ可視 | 可視部分だけの特徴。真の全体寸法を補完しない |
| V06 | nil／ignore／未知材質 | 透明としない。一般的な取得不完了 |
| V07 | 同じ外観の別固定物 | World ID・ハッシュで同定を解決しない |
| V08 | 候補・ray・node・出力上限 | 実操作の上限と不完了状態を検査 |
| A01 | 視覚更新の間に終了する短音 | 有効な聴覚窓へ一度だけ残る |
| A02 | 視野外／背後の音 | 視覚のFOVによって自動除外されない |
| A03 | 既知壁の有無 | 音は規定の減衰で変化。視覚不透明と同一判定にしない |
| A04 | 同じ位置、gain／閾値のみ異なるA/B | 検出差がprofileに従う。意味ラベルは同じく不付与 |
| A05 | 同方向・同時間の二音、単独では閾値未満の二音 | 閾値前に有限混合。源の実数・正体を教えない |
| A06 | 音後に移動・回転 | 過去の受信と方向を新しい姿勢で再計算しない |
| A07 | 窓の開始端・終了端の音 | 規定の片側包含で二重計上なし |
| A08 | buffer溢れ／予算不足／未取得経路 | 無音にしない。coverage・診断に欠落を残す |
| A09 | 発生源を削除、通信応答を遅延 | 既取得の短音が正しい時刻で残る |
| A10 | 失敗したWorld action | 成功に対応する音を偽造しない |
| A11 | プレイヤー音量off／headless | NPC聴覚の取得結果が変わらない |
| A12 | 検出閾値／noise条件の直前・一致・直後 | モデル契約どおりの採否 |
| P01 | A/B切替、片方だけ未取得 | 時刻・ID・profile・状態が同じ個体にそろう |
| P02 | 最新遠景と最新音の取得時点が異なる | 同時刻の完全snapshotとして表示しない |
| P03 | 古い姿勢のframeを表示 | 当時の局所基準と鮮度が分かる |
| P04 | GUIからの読み出し | GET-only。判断・profile変更・emit・cutover操作なし |
| I01 | RW2＋遠景＋音、既定profile | A/Bが独立にdepositとresult admissionを完了 |
| I02 | 同時予算上限 | 個体別枠・全体枠を保持。無制限catch-upなし |
| I03 | 拡張内に座標・音源ID・危険ラベルを注入 | allowlist拒否。ログ全文やlegacy経路へ漏れない |
| I04 | 実Luanti／browserが使えない実行環境 | 未実行と報告。stubのPASSで代替しない |

境界試験は件数だけでなく、**期待する対象の観測内容と、存在してはいけない情報**をharness側で確認する。通常packetへ試験用World IDを付けて検査を簡単にしてはならない。

Pythonの同等式だけでLuaを検証したことにしない。実際に使用するLuaモジュールを通し、幾何・符号・map取得・時計を確認する。ソース文字列にif文があるだけの検査は補助扱いとする。

## 18. 将来接続の位置

### 18.1 感覚間照合と行動

将来は視覚frameと聴覚frameの時間・方向・特徴から、対応候補を作ってよい。ただし同じWorld IDで自動結合せず、複数候補・不明・不一致を残す。

```text
音を取得した
→ そちらを見る候補
→ 視覚で追加取得
→ 同じ出来事かもしれないという対応候補
```

この行動接続は本稿の早期完了条件に含めない。対応候補をcanonical CandidateRelationと同じ型へ自動昇格しない。canonicalへ接続する場合は、採用する観測断面、比較するF/F'、profile変更時の比較適格性を別契約で定める。[T0-S]

### 18.2 嗅覚の保留条件

嗅覚は共通frameの設計上の将来例として残すが、初期の有効channelへ空実装を追加しない。`smell: []`を常時返して「匂いがない」と読ませない。

最初の嗅覚候補は、World側で移動経路へ有限な痕跡を残し、時間とともに減衰させ、鼻付近の粗い濃さだけを読む方式とする。この方式と、風による輸送・拡散を扱う方式は分ける。

導入時に改めて決めるものは、痕跡の所有者、放出条件、減衰則、空間セルと容量、鼻の取得点、混合、World永続化、再送・時刻の扱い。匂いの濃さから正確な源位置や移動方向を直接返さない。

以上は将来の設計候補であり、現在のLuantiに実装済みの機能とは扱わない。

### 18.3 神経・DNAとの分離

固定profileは感覚入力の条件である。将来のDNAや身体発達がprofileのbaselineを与える可能性は残すが、本稿でDNAを追加しない。

同じ情報を取得できても、誤差への反応や報酬が同じとは限らない。反対に、異なる情報を取得することと、高度な推論能力を持つことは同じではない。単一の`intelligence`、`exploration`、`personality`値へ統合しない。

## 19. 推奨配置と移行管理

新設先の例。既存の命名規約とDOBS実装の有無を確認し、必要な範囲だけ追加する。

```text
docs/design/
  RDL_GameAI_Observation_System_Integration_Plan.md

docs/experiment-contracts/
  OBS_common_boundary_contract.md
  OBS_local_profile_compatibility_contract.md
  OBS_distant_observation_contract.md
  OBS_auditory_observation_contract.md

docs/experiment-evidence/
  OBS_common_boundary_evidence.md
  OBS_distant_observation_evidence.md
  OBS_auditory_observation_evidence.md

integrations/luanti/game/rdl_game/mods/rdl_bridge/
  sensor_profiles.lua
  sensor_common.lua
  distant_observation.lua
  auditory_observation.lua

runtime/
  sensory_observation.py

tests/
  test_sensory_observation_contract.py
  test_sensory_noninterference.py
  test_local_sensor_profiles.py
  test_distant_observation.py
  test_auditory_observation.py
```

共通型・純粋関数が大きくなる場合のみ分割する。dynamic plugin registry、汎用service bus、複数の新規repoは初期に導入しない。

Luanti本体は外部依存のままとし、既存の`-LuantiRoot`を再利用する。実機World DB・大量rawログ・音素材を無条件にGitへ追加しない。試験用素材を使う場合は権利と配置を記録する。

旧DOBS文書に、本稿へ計画が統合されたことと旧番号の対応を追記する。文書だけの将来段階をCOMPLETEにしない。旧計画が要求した20項目の受入条件は、C/V/P/I系へ対応を記録する。

## 20. Codexの報告書式

各作業単位の終了時に以下を報告する。

```text
基準HEAD／実装HEAD／変更ファイル
対象OBS段階と、完了・未完了の範囲
既定profile／試験用profile／観測モデル版
実際の入力例・観測例・不正例
実行コマンド・engine/Python版・環境
純粋関数／schema試験
実HTTP試験
実Luanti World試験
p5ブラウザー確認
予算の実測・overflow・処理時間
既存RW2／canonical非介入回帰
未実行事項・残存制約・次の停止点
```

テストを追加したこと、テストが通ったこと、実機で動いたことを別々に書く。「音の数値が取得できた」を「音源の正体が分かる」、「遠景が取得できた」を「山を理解して帰れる」、「個体別設定」を「動物の神経系ができた」と要約しない。

**初回はOBS-0〜2の最小差分で止める。既定profileで既存生活が維持され、異なるprofileで観測差が出ることを確かめてから、遠景・聴覚へ進む。**

---

## 付録A. 参照資料と根拠の区別

本稿の根拠は次の三種類に分ける。数値予算、schema、ファイル配置、段階番号、音の簡易式は、この計画で追加する設計提案である。

### A1. 更新元とユーザーの追加要件

- [D0] 添付 `RDL_GameAI_Luanti_Distant_Observation_Implementation_Plan_v0.1.md`。遠景の取得・記録・表示、既存経路からの隔離、DOBS-0〜5と受入条件を継承する。
- [U1] 今回までに合意した追加要件：局所観測を個体依存へする、将来の動物にも同じ基盤を使う、音は早めに導入する、匂いは後段に分ける。

### A2. 添付RDL資料

- [T0-B] `T0 基底措定 (BASE).md`、正式版v2.3、§2〜4・§8。SILN／RIB／Bと具体実装の責務。
- [T0-S] `T0最低動作仕様 (SPEC).md`、正式版v2.4、§1.1・§4.2・§6.1・§6.4・§8。位置・時間・方向・ρ、同一更新前M_B、各系設計。
- [T1] `T1_SILN操作_総論.md` v2.1、§4〜5。`T1_SILN展開.md` v1.1、§1〜3。`T1_検査と選別.md` v2.1、§1〜2。`T1_再構成.md` v1.1、§1・§4。
- [TD-D] `TD_共有語彙.md` v1.0、§1。`TD_自然言語概念のRDL的翻訳.md` v0.3、§1。Bによる入力差とM_Bによる解釈差。
- [TD-R] `TD_よく使う概念語彙_ρ_無限解像度仮設_v0.1.md`、§7・§10。範囲と解像度、複数の解像度。
- [TD-T] `TD_よく使う概念語彙_時間_v0.1.md`、本文v0.2、§1・§5・§8。通常の後続状態とM_B'の区別、有限時間断面。
- [TD-S] `TD_よく使う概念語彙_空間_v0.1.md`、§4・§7。方向・距離・到達可能性と、範囲拡大のコスト。

### A3. 確認した実装資料

- [R1] 基準HEAD `a19fc2835dcc420ebb2a79a0b3daff7f94ca6e72`。確認日2026-09-26。
- [R2] 同commitの `docs/experiment-contracts/LUANTI_RW2_multi_agent_food_life_contract.md`。
- [R3] 同commitの `runtime/bridge.py` 230〜320行、`/v1/observe`と読取処理。
- 既存L／RW／p5の詳細は、実装開始時にその時点の契約・コード・Evidenceを再確認する。

参照先：`https://github.com/RDL-Labs/RDL_GameAI_Lab/tree/a19fc2835dcc420ebb2a79a0b3daff7f94ca6e72`

### A4. 外部APIとして確認した範囲

- [L1] Luanti公式API `'core' namespace reference`。`get_node_or_nil`と`ignore`、yaw変換、`sound_play`。`https://api.luanti.org/core-namespace-reference/`
- [L2] Luanti公式API `Class reference / Raycast`。selection box基準、map読取と制約。`https://api.luanti.org/class-reference/#raycast`

確認日：2026-09-26。APIの事実と本稿のセンサー設計は別である。これらのAPIの存在から、完全な視覚・聴覚が自動的に提供されるとは扱わない。実装するengine版で実機確認を行う。

## 付録B. 一文圧縮

**観測システム整備とは、同じWorldを各個体の感覚条件・姿勢・時間幅に応じて有限に切り出し、何を取得できたかと何を取得していないかを、解釈・学習・行動へ勝手に昇格させず保持できるようにすることである。**

## 付録C. 旧DOBS受入条件の対応

| 旧ID | 本稿での引継先 |
|---|---|
| A01 機能offのRW2 | C01・C02 |
| A02 回転、A03 横移動、A04 個体別姿勢 | V01 |
| A05 距離境界 | V02。遠景だけでなく近景profile試験C03も別に保持 |
| A06 FOV境界 | V03 |
| A07 遮蔽、A08 部分観測、A09 未取得領域 | V04・V05・V06 |
| A10 有限予算、A11 状態区別 | V08・I02・C06 |
| A12 禁止情報、A13 再送、A14 個体混線 | I03・C08・C07 |
| A15 容量・古いframe | C09・C11 |
| A16 既存経路への非介入 | C12 |
| A17 p5、A18 実RW2併走 | P01〜P04・I01 |
| A19 既存実機回帰、A20 未実行の明示 | C01・I04 |

旧DOBSの工程は、DOBS-0→OBS-0/1、DOBS-1/2→OBS-3、DOBS-3→OBS-1、DOBS-4→OBS-5、DOBS-5→OBS-6へ移す。旧DOBS-6/7の照合・方位利用はOBS-7/8として保留を維持する。

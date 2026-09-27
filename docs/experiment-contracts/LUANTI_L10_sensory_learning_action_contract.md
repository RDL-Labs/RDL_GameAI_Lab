# Luanti L10 — 学習したM_Bによる有限Food行動選択

状態: IMPLEMENTED。実行結果は[Evidence](../experiment-evidence/LUANTI_L10_sensory_learning_action_evidence.md)。
基準: `7f7ed83`。観測v1の完了条件・既存policy・旧L7の契約は変更しない。

## 問いと成立条件

同じ観測・経験・固定選択規則から作ったrelationを、T1-Cで再構成したM_Bへ採用し、
そのモデルを実際に切り替えることだけで、後続のLuanti身体行動が変わるか。

```text
共有センサー → Runtime受理済みframe → 明示Purpose/Bによる断面
→ 現在M_Bの解釈・予測 → 固定選択規則 → 有限Food試行／保留
→ 実World結果 → 直接参加Experience
→ 3経験で条件別relation形成 → 未使用の1経験で検査
→ 明示T1-A/B/C → inactive M_B' → 明示cutover
→ 次の観測を新しいM_Bで解釈 → 実行差
```

成立を「モデルIDが変わった」だけで判定しない。予測値、採用relationの出典、選択理由、
実際の移動・取得・帰還を対応づける。更新を反映しない対照でも同じ材料からinactive artifactを作る。

## 有限境界

- Purpose: `predict-bounded-food-attempt-from-distant-color`。
- 装置条件: `l10-fixed-food-apparatus-v1`。各Episodeの同じ開始位置・向き・Food位置・身体条件。
- 同run/epoch/agent、同profile ID/版、同sensor model/clockに限定。
- 許可profileは既存life sensory 2種のrevision 1。遠景モデルは`sampled-surface-v0.2`。
- 完全取得・出力省略なしの遠景frameに特徴が1件あり、水平角区間が[-5,5]内、色が既知。
- 取得から決定要求まで500000µs以内、身体操作開始は取得から1000000µs以内。
- 1run最大16操作、1Episodeにつき1操作。明示形成6件・検査2件、2条件に各3＋1件。
- 1runの再構成は最大1回。結果の受付期限は決定要求から5秒。
- Luaの取得試行は最大16step。固定Foodへの接近・取得・帰還・depositであり、一般経路探索ではない。

粗い色はこの装置内の観測条件である。色に普遍的な成功／危険の意味を与えず、対象ID・音源IDにも
しない。隠れた通路条件を変えると、同じ色でも結果が変わる。因果同定の主張はしない。
`--luanti-learning-loop`の有効化は、この有限装置runを使う明示宣言である。
frameだけから身体・装置条件の同一性を証明するものではなく、その条件は専用World fixtureで検査する。

## 取得とWorldの権限

遠景は既存`distant_sensor.lua`、聴覚は既存受信窓・伝達モジュールを使う。
各Episode開始時に近景・遠景・聴覚の3frameを一度取得し、既存`/v1/observe`で受理する。
学習入口は受理済みframe IDを明示参照し、暗黙の最新frameやWorld内部情報を参照しない。
この初版で予測に使う感覚は遠景の色条件のみ。近景・聴覚は同run内の取得記録として保持する。

WorldがFood entityと壁nodeを配置する。壁がある場合は次の移動先nodeで接近が止まり、Foodを取得しない。
壁がなければ実entityへ接近し、取得時にentityを除去し、Baseへ帰還する。移動は既存RW2と同様の
有限なkinematic操作であり、汎用物理エンジンによる歩行シミュレーションではない。
壁状態・真の位置・実験者期待値はWorld Evidenceにのみ置き、決定要求へ含めない。
結果の`food_acquired`は身体側が報告した直接参加事実として受理する。

HTTP待機中もWorldの時計は進む。身体作用はglobalstepでのみ実行する。
決定を同じ完全入力で再要求しても同じdecisionを返す。Lua操作台帳は実行権限を先に消費する。
操作内容変更、結果内容変更、別操作へのevent再利用は拒否。台帳はprocess内のみ。

## M_Bの実行可能なrelation

既存`FrozenGameAIMB`へ`interpret_sensory_food(section)`を追加する。
通常のcount用`interpret(section)`は変更しない。M_Bは従来のcount解釈に加え、明示的な補助境界の
typed relation `sensory-food-table-v1`を持てる。relation自身がPurpose、装置条件、run/agent/profile等の
適用境界と形成・検査Experienceを保持する。この補助境界をcount次元へ暗黙に混ぜない。

採用前・未経験条件は`unknown / values=null`。未知を成功・失敗・数値0へ変換しない。
採用後だけ、その色条件に対応する取得予測0/1を返す。legacy relationに実行権限を追加しない。
consumerはactive registryのM_Bを明示取得する。inactive artifactは行動判断に使用しない。

固定action規則:

| 状態 | 選択 |
| --- | --- |
| 取得・鮮度・適用条件不足 | defer |
| 完全な断面だが未学習 | attempt_food（有限探索） |
| M_Bが取得を予測 | attempt_food |
| M_Bが非取得を予測 | defer |

counter、Episode番号、色名そのものを成功／失敗判定へ使わない。対象候補・有限な試行方法と
この選択規則は設計側から与える。方法の発明、自律的な注意、一般Goal/Trajectory生成ではない。

## 帰納・検査・T1

形成6件を観測色条件ごとに分ける。各条件3件が同じ結果ならrelation候補を作る。
未使用の別Episode/eventの1件が一致すればRETAIN、不一致ならREJECT。
形成側が不一致ならDEFERし、実行可能relationを作らない。
形成支持数は3、検査数は1。event再送・relation数・再評価を支持数に足さない。
未試行のdeferには取得結果もExperience票も作らず、結果受付記録だけを残す。

既存T1-A/B/Cとcutoverを使う。T1-Bには全材料のdispositionを記録する。
current M_BはRETAIN、候補は検査結果、その他の材料はDEFER。
形成・検査材料、独立canonical review、activationの指定はharnessが明示する。
Sleep行動・NERV profile・SOC候補をこの入口へ自動転用しない。

**再編の起動は自律化しない。** 既存L7と同じく、Worldから受け取ったcount比較のEについて
harnessが明示reviewし、その実験基準の未吸収残差から既存M_deltaへ入る。
Food出現／消失を普遍的に「未吸収」とする規則ではなく、独立した有限review条件である。
Candidateの支持数や取得失敗をそのままE/Hにしない。

## 予測後の観測・比較

決定時にM_Bを固定する。結果受付は後でactive modelが変わっていても同じモデルを使う。
before断面は条件からの予測、after断面はその操作の取得結果の解釈として、同じ
`food_acquired`次元へ写す。既存`compare_interpretations`でF/F'の差を形成する。
モデル・個体・補助境界が異なる比較を拒否する。

学習前はFがunknownなので比較不能。保留は未試行であり、予測の確認にも反証にもならない。
学習後に成功予測へ実失敗が来た場合、同じM_Bによる差-1を残す。
この補助境界の差は記録までとし、count用assessmentへ混入させず、H／次の再構成を自動起動しない。

## 実機比較と停止境界

3つの独立runに各12Episode:

1. activationなし。形成・検査・inactive再構成は同じ、以後も親モデルを使う。
2. activationあり。通常の色と通路条件の対応で予測から実行する。
3. activationあり、形成時から色と通路条件の対応を逆にする。規則の色名依存を検査する。

各runの1〜6は形成、7〜8は未使用検査、9〜10は同条件の再入試行、11〜12は隠れた通路条件を反転。
11〜12では、保留して新しい成功機会を観測しない場合と、成功予測を裏切る失敗を分ける。
対照間で初期装置・固定規則は一致させ、分岐後の観測・経験列の一致は要求しない。

今回の到達点は専用Luanti fixtureの単一個体。OBS-9のA/B周期取得＋Probe＋生活調停への常設統合、
既存RW2 policyの全面置換、NERV/SOC接続、一般姿勢変換、長期学習、自動Sleep／review、
反例後の二度目のT1循環は未実装。観測v1の既存回帰を維持する。

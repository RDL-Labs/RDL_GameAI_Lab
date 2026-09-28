# L15A — 固定左右バイアス単独実験

状態: IMPLEMENTED / WORLD ACCEPTANCE COMPLETE。基準 `f63d6a7`。
全体回帰での既存HTTP試験1件の接続中断と、当該モジュールの再試験結果はEvidenceへ別記する。
[v0.3計画18A](../design/RDL_GameAI_Luanti_Subjective_Movement_Terrain_Extension_Plan_v0.3.md#18a-個体固有の左右バイアスと旋回安定化)を有限に具体化する。
[Evidence](../experiment-evidence/LUANTI_L15A_lateral_bias_evidence.md)。

## 範囲

schema `l15a-terrain-lateral-bias-v1`、rule `l15a-lateral-near-tie-v1`。
既存の[探索接続v1](LUANTI_L15A_exploration_connection_contract.md)だけを継承し、
[旋回安定化v2](LUANTI_L15A_steering_contract.md)の短期方向保持・旋回後の一歩・旋回打切りは取り込まない。
両modeの同時指定は拒否する。biasだけで振動が減ることを成功条件として埋め込まない。

新しい係数はGameAI-localな初期設定であり、personality label、学習済みM_B、Core E/H/θ/M_deltaではない。
Food/obstacle/physicalの純粋計算、sensor、World衝突判定、接近予算24、既存の採取・独立検査・M_B経路は保持する。
身体状態・未知価値・社会relation・広域価値は今回追加しない。

## 固定設定

各個体のconfigureで `lateral_bias = left | neutral | right` を明示する。
初回の正当な受付後はrun中固定。同一設定再送は許容し、変更・未指定・不正値・run/agent不一致は拒否する。
拒否前にbiasを公開しない。A/B/CのIDやsteady/curious/restlessから自動推定しない。

固定値は、左右差の許容幅 **0.10**、一方向の最大寄与 **0.05**。
元の地形と同じ数値単位に対する局所定数であり、物理精度・神経感度一般を表さない。

## 適用条件と合成

現在の完全取得から計算した5方向 `-90, -45, 0, 45, 90` を使う。正の角度は身体の右。
鏡像方向の組 `(-45,+45)`、`(-90,+90)` ごとに、すべてを満たす組だけを適格にする。

1. 元地形のstatusがcompleteであり、両方向ともscored。
2. 元のglobal minimumに正面0度が含まれない。
3. 少なくとも片方が元のglobal minimumに含まれる。
4. 左右の `physical / food / obstacle / total` **それぞれ**の絶対差が0.10以内。

比較誤差は既存と同じ1e-9。大きな成分差を相殺したtotalだけの同点を適格としない。
最良方向でない遠い候補をbiasによって選択へ持ち上げない。

適格な左右組にだけ、次を付加する。

| bias | 左寄与 | 右寄与 |
| --- | ---: | ---: |
| left | -0.05 | +0.05 |
| neutral | 0 | 0 |
| right | +0.05 | -0.05 |

`final_total = observed_terrain_total + lateral_bias_contribution`。
非適格な数値方向と正面の寄与は0。除外・未取得で元totalがnullの方向は、bias・finalもnull。
元の観測値や成分を改変せず、別の出力に保存する。

最終最低値からの選択はv1の既存規則を使う。
正面が最低ならmove 1、左右の絶対角が同じ同点ならwait、それ以外は最小絶対角の唯一方向へturn。
neutralではv1の同点処理・commandが維持される。
強い差・閉塞・no_surface・過大段差をbiasで解除しない。partial/unavailableは数値化せずwait。

## 出典と身体作用

各該当decisionの `lateral` に、現在観測のraw terrain、pairごとの適格性・成分差、
observed total・bias contribution・final total、固定設定のrun/agent出典、bias前後のactionを保存する。
`turn_hysteresis = disabled`、その寄与はnull。未実装の短期慣性を0値の観測として偽装しない。
直前の実旋回yawは診断にだけ保存し、選択には使わない。次観測参照は実行後の再生記録の`decision_links`に保存する。

後方Foodへの従来向き直し、pickup、variation、Foodなしの目印探索、所持品・身体・時刻ゲートはv1/L14Bの優先順位を保つ。
既存controllerの取得姿勢・期限・個体別operation IDで有限作用を実行し、再送でbiasや作用回数を増やさない。
グローバル地図・未観測座標・資源残量・将来の成功結果を入力しない。

## 固定した比較

草地の近傍2資源と自然林の8資源を使い、各地点12単位、seed20260928、3個体×2periodで各3run。
L14B profileは毎回A=steady/B=curious/C=restlessのまま、次の固定設定だけを変える。

| run条件 | A | B | C |
| --- | --- | --- | --- |
| neutral | neutral | neutral | neutral |
| mixed | left | neutral | right |
| swapped | right | neutral | left |

全6runを事前固定して保存する。草地と自然林のどちらでも結果の良いseedやprofileを選び直さない。
故障注入はoffとし、現在のbias差を観察する。通常の操作再適用・個体混線拒否は既存fixtureで毎回検査する。
初期条件は同じだが、閉ループで変わる後続観測・HTTPタイミング・資源競合は同一ではない。
同一観測でbiasだけ変える純粋な比較と、異なる軌跡による経験差を分ける。

保存する指標は、個体別turn/move/wait・連続逆旋回対・最大連続turn・pickup・終点・軌跡。
訪問域の補助指標はWorld監査側の2ノード四方のセル数で、Runtimeへ戻さない。
取得されなかったFoodや未訪問地を知っていることにはしない。

左右対称の正例・鏡像・強い差・成分相殺・幅境界・欠測・ID/配列順の非依存は合成入力で試験する。
自然Worldの地形全体を左右鏡像にした実験とは区別する。

### 主比較後の追加診断

6runでA/Cには適格な左右組がなく、草地Bの1件だけが適格だった。Bは全主比較でneutralだったため、
採取・軌跡・振動にbiasによる差は出なかった。この6runを保存した後、
草地について全員left / 全員rightの2runを追加する。係数・幅・World・既存profileは同じまま。
主比較後の探索的な診断として別のprovenance/再生ファイルへ保存し、初めから予定した8runと記述しない。

## 停止点

今回の到達点は「弱い固定biasが有限な近同点を分け、後続の実行差や振動へどう作用するかを記録できる」。
自然な歩行・一般回避・採取効率・生得性・学習によるbias形成は保証しない。
短期方向維持との合成は、単独実験の結果を確認した後の別変更とする。

# SOC-0 Heavy Rescue 最小社会依存実験

状態: **IMPLEMENTED / SOC0-01〜10 PASS** / 2026-09-27。
基準: `ac8853a`。[着手計画](../design/SOC_0_social_dependency_plan.md)、[Evidence](../experiment-evidence/SOC_0_heavy_rescue_evidence.md)。

## 問いと実装範囲

A単独では成立しない搬送が、別個体Cの有効な身体参加によって成立するか。
Godotの既存World providerを継承する`heavy_rescue_fixture.gd`に限定したopt-in実験。
通常provider、RescueTrajectoryPolicy、Luanti生活経路は変更しない。
既存Rescue/RecoveryはGodot側にあるため、SOC-0をLuantiへ新規移植しない。
Godot mock worldでの実resolver・位置変化・BodyState更新であり、剛体力学や連続的な協調運動の再現ではない。

## World成立条件

初期値はA/C能力1、B荷重2。値はWorld専用変数で、bounded observationへ追加しない。
harnessが搬送参加集合を明示する。参加者は実在・重複なし・対象以外・行動可能・対象のRescue範囲内であること。
他対象を運搬中の個体は除外する。A自身も有効参加している必要がある。
有効参加者の能力合計が荷重以上の場合だけ既存`_resolve_rescue`へ渡す。
通常のrescue actionを実resolverへ送った後に判定し、足りなければBを移動・attachしない。

搬送中のapproach/deliverでも有効参加を確認する。参加不足なら進行しない。
既存A→B attachmentと移動・deliveryを使い、共同参加Cは同じ移動差分で追随する有限な運動fixture。
A/Cの独立した経路選択や同期学習は行わない。delivery後は既存safe-placeの4段階Recoveryを使う。

## 有限性と配送境界

1 fixtureにつき新規carry試行最大2回、action受付最大64件。harnessは最大30決定で停止。
同じ個体/観測ID・同一decisionの再送は既存result、内容変更は拒否。すでに運搬中の対象は二重attachしない。
失敗carry自体のEnergy消費は0。無制限にEnergyを減らす失敗ループはない。
移動時は既存Energy機構を有効にした場合のみ、既存approach消費を参加者に適用する。
初版の操作台帳はprocess内だけであり、永続一回実行保証ではない。

## Experienceと情報境界

Worldが出力した`source_observation_id / subsequent_observation_id`付きの作用結果を、
`RescueExperienceStore`へ明示的に取り込む。実験ではGodotのJSON書出し→Python受理/再生という経路。
HTTP新endpointや既存Experience/Outcomeの自動接続を追加しない。

`schema=soc0-rescue-experience-v1`。個体、run、event、tick、target、実際の有効参加者、
solo/joint条件、carry成立/不成立・delivery、移動有無、bounded body consequenceを保存する。
World内部の荷重・能力合計・必要人数・推奨helperを含めない。
参加者IDは実参加の記録であり、成功を約束するhelperの推薦ではない。
形成できるのは`bounded-Experience-only`の局所記録。友情・信頼・役割・社会価値を作らない。

Storeは最大16件、run一致・厳密field・結果整合性を検査。
同event同内容は同結果、変更再送・容量超過は拒否し部分更新しない。
能力情報を紛れ込ませた余分なfieldも拒否。保存snapshotはコピー。
この検査は報告の整合性であり、外部Worldの真正性認証ではない。

## 受入

SOC0-01〜10はEvidenceの有限実験範囲でPASS。
主runはAが近づき単独失敗後、同じB・同じ位置条件のままharnessがCを有効参加させ、搬送→delivery→recoveryする。
Cは初めから近くにおり、存在だけでは報酬や成功にならない。
通常のRescue Runtimeは有限な観測だけからAのapproach/rescue/deliverを選ぶ。
Cの参加意思と移動協調はharness/World fixtureが設定する。

単独能力2ならattach成功、2個体でも荷重3なら失敗、重複・遠方・行動不能の参加者は加算しない。
途中参加解除で搬送進行が止まることも確認する。

自律help seeking、Communication、誰を呼ぶか、社会relation、NERV勾配・Bias、T1・M_B・行動学習は未接続。
**有限な単独失敗と共同成功を記録したところで停止する。**

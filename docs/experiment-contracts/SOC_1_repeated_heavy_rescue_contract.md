# SOC-1 Repeated Heavy Rescue

状態: **IMPLEMENTED / 有限3 Episode比較PASS** / 2026-09-27。基準: `fb874fd`。
[Evidence](../experiment-evidence/SOC_1_repeated_heavy_rescue_evidence.md)。

## 有限な問い

独立した3 Episodeを同条件で実行し、過去Experienceへのアクセスだけを変えた二条件を比較する。
全EpisodeでA/C/Bを使い、selectorも固定したactor/target/helper範囲の記録だけを受理する。
World・身体・操作台帳・Rescue Runtime・既存canonical/historyを初期化する。
引き継ぐのはSOC-1 selectorの有限Experienceと監査記録だけ。対象一般化やB/D間の差は試験しない。
Episode ID/world run IDは別とし、時系列は明示した開始・終了順だけで管理。番号解析で選択を変えない。

## 候補と固定規則

初期候補はsolo、joint、defer。harnessが実行可能な条件一覧を明示し、重さや能力値を渡さない。
共同条件を候補として提示すること自体は設計者が与える操作語彙であり、学習した発見ではない。
現在Episodeで失敗済みの条件を除外。残る条件を、過去delivery成功Episode数が多い順、失敗Episode数が少ない順、同点ならsolo先で選ぶ。
どちらも実行できなければdefer。成功根拠は対応するattach→deliveryを持つ記録のみで、attachだけは成功支持にしない。
関係は同じA・同じ対象B・行動不能搬送という固定文脈の局所対応。友情・信頼・普遍的協働則ではない。
この固定の検索/選択規則を学習しているのではなく、その規則へ入力される記憶が変わる実験である。

保持ありは終了した過去Episodeを参照、保持なしは現在Episodeの記録のみを参照する。
保持なしでも監査用に過去記録を残すが、選択根拠に使わない。両者は別instance/ledgerで走らせる。
現在Episodeの失敗を両条件で使用する。Episode 1に専用のsolo→joint分岐を作らない。

## 実行・出典・予算

`RepeatedRescueSelector`が条件を選び、専用test harnessが参加者集合を実現する。
既存Godot SOC-0 providerと既存RescueTrajectoryPolicyがapproach/carry/delivery/recoveryを実行する。
selectorの入力はSOC-0のbounded作用結果だけ。通常Runtimeに新しいendpointや既定policyは追加しない。
選択HTTPは試験専用handler。先のEpisodeの結果は選択前に取得/投入しない。

最大3 Episode、各最大3 eventと3条件選択、World側は既存最大2carry試行・64 action受付・30決定。
各選択に候補、成功/失敗のepisode/event参照、accessible履歴、選択理由を凍結保存する。
再送は同choice ID・同payloadなら同結果、変更は拒否。eventのprefix変更/省略、別run/個体/target、重複event、deliveryだけの成功偽装は拒否。
完成前の履歴追加は検証後に公開し、入力拒否で選択履歴を部分更新しない。
初手、solo試行数、solo retry数（最初のsoloを除く）、joint選択/実成立、action数、成功までのaction数、Recovery、deferred/incompleteを保存する。
成功までのaction数はdeliveryを含み、完了観測idle・準備用Bのflee・Recovery4tickは含めない。

## 受入（完了）

1. 保持あり/なし各3Episodeを実Godotで実行し、同じ初期World条件・毎回初期化を確認。
2. 初回の選択と結果が一致。保持ありの次回選択に前Episodeの実受理記録が参照される。
3. 保持なしは過去Episodeを選択根拠へ混ぜず、現在失敗だけで代替条件を選ぶ。
4. 成功選択への変化がEpisode ID/番号やfuture結果で決まっていないことを局所試験。
5. 両条件でcarry/delivery/recoveryを既存経路で完了。記録と実行した参加条件が一致。
6. 試していないsoloの成否を記録しない。action削減と選択差、学習規則/個体性/援助要請の主張を分離。
7. defer/incomplete、両条件失敗、候補利用不可、attachのみ、入力不正・容量・再送を試験。
8. 社会relation・NERV/T1・M_B変更はなし。SOC-0、既存Rescue、主要回帰を確認。

行動差の主張は「明示候補の条件選択が、保存経験によって変わった」まで。
Cの援助意思・Communication・自律的な候補発明・身体由来の性格差・永続記憶は含めない。

## 実装配置と信頼境界

`runtime/repeated_rescue.py`に独立selector、`tests/test_repeated_rescue.py`の専用harnessと
`godot/.../tests/repeated_rescue_http_check.gd`を追加した。通常bridgeのendpointやpolicyは変更しない。
条件選択はEpisode開始時とcarry失敗後のみ。選択後の作用結果は選んだ条件と照合し、未選択の条件を経験として受理しない。
現在のEpisodeを終了してから次を開始し、履歴の同run/episode再利用を拒否する。
終端statusとdeliveryの整合を検査し、成功としては対応するcarry→deliveryの列を要求する。
finishの再送受付は実装しない。終了後のfinishはactive Episodeなしとして拒否する。

World初期条件・現在の利用可能候補・参加実行はharnessの責務。受理済み報告の真正性を外部認証するものではない。
保持なしの監査archiveを選択へ使わないことを検査したが、完全な記憶消去やプライバシー機構ではない。
専用13テスト、実Godot 6 Episode、SOC-0/既存Rescue回帰をPASS。
DEFER・incomplete・両条件失敗の分岐はPython局所試験であり、6実Episodeは全件完了ケース。

## 次工程（SOC-2の有限比較を実装）

[SOC-2契約](SOC_2_rescue_selection_tolerance_contract.md)は、同じ経験集合を保持したまま
固定許容条件による選別差を調べる。SOC-1の履歴保持比較と既存selectorはそのまま固定する。
SOC-2は専用実Godot記録の再生と局所選別まで実装・受入済み。次Episode行動やNERV/T1への接続は含まない。

[SOC-3契約](SOC_3_selection_guided_rescue_contract.md)では、SOC-1の順位付けを共用しつつ、
過去3件の検査材料と新しい1 Episodeを専用adapterで分ける。既存の3 Episode上限やarchiveへは介入しない。
SOC-3の次Episode行動接続は実装・受入済み。順位付けだけを純粋関数として共用し、SOC-1の旧結果・上限は維持した。
[SOC-3 Evidence](../experiment-evidence/SOC_3_selection_guided_rescue_evidence.md)。

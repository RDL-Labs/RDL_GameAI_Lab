# Luanti L13A — 色タイル・遠景を伴う有限探索

状態: IMPLEMENTED / FINITE ACCEPTANCE COMPLETE / l13a-v1 / 2026-09-27。
基準: `df2d23d` ＋ 本実装working tree。実行結果は[Evidence](../experiment-evidence/LUANTI_L13A_finite_exploration_evidence.md)。

## 問いと停止境界

未知Foodを局所観測で発見し、相対移動と実pickupまで通せるか。
昼間固定、単独npc_a、平坦地、色帯（直線／右曲がり／左曲がり／回転配置）と山3か所。
帯なし・Foodなし・取得不完了・通信故障も比較する。全runの取得成功は要求しない。
固定の色追従規則は設計者が与えたもの。山は受理済み遠景記録まで。
経路記憶、目印の同定、T1/M_B学習、夜間、消耗、死亡、複数個体は未接続。

## 有限な取得と入力

World時計はHTTP待ち中も進む。取得枠250000us、16秒まで最大64枠。
各枠で地表色9点、半径12のFood観測（最大1件）、共有遠景センサー1回を同時取得する。
地表は身体基準の中心と前後左右の距離1／2node。色はblue／gray／unknown。
地表rayの遮蔽・未ロード・表面なしはunknownとPARTIAL。視野は専用の下向き近接取得計画であり、
一般画像認識ではない。色はWorld nodeの登録色から取得し、全配置表を個体へ渡さない。
地表用l13a-ground-nine-v1は専用取得記録。旧vision_local payloadを変更しない。
遠景はfixture-distant-enabled、距離(12,64]、水平90度・垂直60度、最大4特徴の既存規則。
SensoryObservationStoreで受理する。山の表面候補は試験前に固定し、World IDや座標は配送しない。
全記録にrun／epoch／agent／clock、取得時刻・取得枠・姿勢・profile・欠落を残す。
Foodは範囲内だけref・距離・身体基準forward/rightを配送する。初期観測にFoodは含まれない。

## 固定選択と身体権限

現在見えたFoodがreach1.25以内ならpickup、それ以外は相対方向へ回転／一歩移動。
Foodがなく取得不完了ならwait。直前の移動がblockedなら右回転。
それ以外は青い近接セルを前→右→左→後の順で参照する。後方は右90度を選ぶ。
青がなければ前方を一歩試す。2node点も観測に残すが初版選択は1node点を使用する。
この規則はrun名・配置名・未観測Food・山・絶対座標を参照しない。
一操作は前進1node、水平回転±90度、pickup、waitのいずれか。
最大64許可消費（wait・失効も台帳の1件）、総移動64node、総回転5760度以内。並進はkinematicで、0.25node刻みの衝突・床検査後に実行。
移動不能時は位置を変更せずblocked。見えたFood refでもWorld側の現在reachを再検査する。

応答は観測ID・姿勢参照・身体revisionに束縛。期限は取得後500000usとrun終了の早い方。
callbackは受渡しだけ、作用はWorld stepで台帳を消費してから実行する。
実測変位／yaw・実行時刻・前後revisionを結果記録する。指令を実行結果としてコピーしない。
同じ操作IDは再実行しない。入力変更は競合。失効・身体変化・終了後は作用せず理由を返す。
再送は同じ受理済み記録／同じ操作を返し、原取得時刻を更新しない。
pending上限8、単一HTTP送信、保存／操作台帳上限64。満杯や枠の逸失は機構エラーとして停止し、未達と混同しない。
古い記録を勝手に捨てない。実測最大pendingは故障ケースの4件。

## Worldと結果

歩行範囲はx/z各[-32,32]、y=1。帯と地面は同じ高さ・通行条件。昼時刻固定、World経過時計は継続。
直線Foodは(0,1,26)。曲がりはz=12付近で±x方向へ延び、Foodは(±24,1,12)。
回転配置は初期yaw・帯・Foodを90度共通変換し、山の配置は固定する。これらは実験者だけの設定でRuntimeへ送らない。
帯幅2node。遠景の岩山3体は歩行区画外側、露出表面候補を固定。色と方向だけを記録する。
取得成功で終了、未取得は16秒でtime_limit。身体資源の行動不能や死亡とは呼ばない。
終了後は作用を止め、配送・結果受付だけ有限に処理する。通信失敗／例外は未達と混同しない。

実機比較: straight / right / left / rotated / no_strip / no_food / partial / blocked / faults。
partialは地表読み取りの未取得注入、blockedは取得後に実node障害物を挿入する。
故障は成功応答破棄・同一観測再送、期限超過の受渡し、旧応答の操作consumerへの再注入。
実ネットワーク切断・再起動をまたぐ一回実行保証ではない。
Python固定入力検査、Lua作用境界検査、実Luantiと受理済みwire再生を別々に記録する。
既存L12 positive_active/A・OBS-9 faults・OBS-3を実機回帰。L13各run前後のHistory／canonical不変を検査する。
既存ActionはL13専用経路へ切り替えず、全体Python回帰も実行する。

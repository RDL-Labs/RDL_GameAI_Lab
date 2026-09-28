# L15A — 有限な ξ_tie 単独実験

状態: IMPLEMENTED / FINITE WORLD ACCEPTANCE COMPLETE。基準 `122e4f4`。
[v0.7](../design/RDL_GameAI_Luanti_Subjective_Movement_Terrain_Extension_Plan_v0.7.md)の微小摂動だけを実装する。
以下の定数・比較を実World実行前に固定した。[Evidence](../experiment-evidence/LUANTI_L15A_tie_break_evidence.md)。
主比較で移動改善は認められず、適用条件外の停滞は残った。

## 入口と権限

schema `l15a-terrain-tie-break-v1`、sampler `sha256-ranked-near-minimum-v1`。
configureで `tie_break_mode = disabled | frozen` を明示し、run中固定する。
探索接続v1を使い、左右傾向はneutral、方向維持はdisabled。
steering v2 / lateral biasとの同時指定は拒否する。pickup、所持品、身体対応、
既存の学習・variation・目印探索の優先ゲートは変えない。
`tie_break_perturbation` はGameAI局所選択の寄与で、Core ξ/E/H、M_B更新ではない。

## 適格性と選択

現在のcompleteな地形で、scoredかつ最低値から0.10以内（誤差1e-9）の方向を**全部**候補にする。
2方向以上あり、その集合内のphysical / food / obstacle各成分の最大差も0.10以内のときだけ適格。
成分の強い相殺、partial / unavailable、blocked / no_surface、未取得は拮抗の証拠にしない。
前向き0度も含む。v1の「正面が同点なら前進」はこのmodeの適格な拮抗では置換される。
これは局所移動選択だけであり、上位のpickup等の優先順位を変更しない。

`SHA256(JSON([master_seed, run_id, agent_id, tie_episode_seq, sampler_version]))` をseedとする。
JSON規約は既存digest（sort_keys、区切り`,`/`:`、ensure_ascii=False、UTF-8）。
seed整数を5,4,3,2,1で順に除算した余りから5方向の順列を得る。
順位0〜4を `-0.05, -0.025, 0, +0.025, +0.05` へ割り当て、適格方向だけへ加算する。
最終最低値がなお誤差内で同点なら同じseed順位で分ける。参照IDや配列順で左右を決めない。
候補外を選択へ昇格させず、地形差の大きい方向・取得不能方向を救済しない。

元terrainと最終選択値は別に保存する。非適用寄与はnullとapplication_status、
計算された0はappliedの0として区別する。UNKNOWN IS NOT A TIE。
disabledは診断だけを保存し、v1と同じcommandを返す。

## 局所局面の保持

1局面につき最大3判断、最初のcapture_usから750000µs以内。period/run終端でも失効する。
直前の受理済みdecisionからだけ引き継ぐ。次の条件をすべて満たす場合だけ同じseedを再使用する。

- 連続する取得枠で、適格方向集合と観測中Food参照集合が同じ。
- 直前操作の実結果がturned / waitedで、並進していない。
- 実結果の姿勢・revisionが現在取得と一致し、結果時刻が取得より前である。
- 直前commandの期限、局面期限、使用数上限を超えていない。

毎回新しい取得値で適格性を再計算する。旋回後の値は現在の身体相対方向へ適用する。
同じWorld方向・同じ物体の追跡や旋回指令からの姿勢変換を意味しない。
移動、結果欠測・不一致、取得不足、候補変化、優先行動への移行で旧局面を閉じる。
その時点で別の適格局面があれば新番号で開始できる。失効を理由に未観測方向へ進ませない。

seedは新局面の**正当な観測受付**でのみ進む。同一観測再送は同じdecision/commandを返す。
競合・受付失敗で使用数を消費しない。状態は既存の有限な受理済みdecisionログ内に保持する。
start/current source、直前operation、局面参照・使用数・期限・終了理由、seed入力と全順位を保存する。

## 比較と記録

3個体、各地点12単位、2period、master_seed=20260928、A/B/CのL14B profile固定。
草地の近傍2資源、自然林8資源それぞれdisabled/frozenの4runを主比較とする。
別途、草地frozenの1runで応答消失・遅延・旧callbackを注入する。全5runを事前固定する。
run_idもseed材料であるため各runのseedを保存し、結果を見てseedや係数を選び直さない。
独立した閉ループrunはHTTPタイミングや後続観測まで同一とは主張しない。

実取得・身体readback・全HTTP記録を保存し、exact replayで再検証する。
turn/move/wait、逆旋回対、最大連続turn、採取に加え、並進なし時間、2ノードセル滞在・訪問数を記録する。
並進なしは達成なしと同義ではない（その場の採取もある）。セルは実験者のWorld監査専用。
逆旋回が減っても、待機や同じ領域への停滞が増えれば改善と断定しない。
同一観測のdisabled評価と摂動後評価を分け、後続軌跡の差と混同しない。

## 停止点

有限な拮抗を再現可能に分け、実作用と限界を追えることまで。
脱出、自然な歩容、経路最適化、採取効率、長期的な偏りの解消を保証しない。
thinking delay、観測/判断周期変更、反復残存/減衰、停滞検出、追加観測、興味・目的変更は実装しない。

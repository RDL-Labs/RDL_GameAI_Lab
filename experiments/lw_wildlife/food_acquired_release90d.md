# 食料確保で解除する90日比較

開始H20、摂取量>0で再検討解除。摂取による親H冷却は継続、局所Hは消去しない。H低下だけではモード解除しない。再度SEARCHで目標選択する際は残存Hで再発動可能。採食中の選択は従来どおり行わない。
release_on_intake=trueは暫定固定、falseで旧H<=10解除。設定はconfigured_pathsへ隔離。将来は食料確保の試行成果へ共通化。
食料が見えただけ/量0では解除しない。未初期化予測を食事で作らない。12境界/成果検査PASS。
同一入力・シードの初日から90日、兎100/捕食者1/人なし、草倍率1.5、泳ぎあり、auto、diverse/patchy/distributed/layered。
出力C:/Users/ken_m/Documents/Codex/rabbit-food-acquired-release90d-20261109。
比較元rabbit-food-threshold20-cooling90d-20261109は90日正常完了、458.9732秒。凍結ソースを維持。
完了判定はexit_code=0とcompleted.json verified=true/90日。起動時点では結果未確定。

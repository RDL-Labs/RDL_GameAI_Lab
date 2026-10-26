# 日別経路図

実行例: `node experiments/rock_gate/render_daily_paths.cjs outputs/no-hazards-ordinary-30d-20261026 ordinary`

各caseのinput.json、positions.json、report.jsonを読み、daily-pathsに日別PNG/SVG、summary.json、日付スライダー付きindex.htmlを生成する。第3引数で出力先を変更可能。sharpは既存render_paths.cjsと同じローカル依存パスを使用。

全日・全個体が共通縮尺。時間を青→紫で表示し、白丸が開始、黒丸が終了。拠点、人工道、障害物、初期食料位置を重ねる。食料アイコンは残量を表さない。終了エネルギーと拠点距離を併記。

通常のrunnerは60秒ごとの位置保存であり、描画はその間を直線でつなぐ。実移動距離・衝突・経路の細部はこの補間図から判断しない。詳細確認には新規試験で--trace-every-tickを指定する（ログ増大）。初日開始はscene.positions、以降は前日最後の位置を使う。地形の水域は未描画。

30日試験の全90パネルを生成済み、9日目PNGを目視確認。A/Cが北西側へ滞留し、Bが南側の食料地点付近へ移動する違いが見える。ただし認識・選択の原因は位置図だけでは確定しない。

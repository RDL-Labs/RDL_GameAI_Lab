# 焚火休息・人物接近・名前呼びの10日接続

通常LWにscene.meeting_name_calls=false既定を追加。人間関係・camp_trade_calls・
peer_identity_rosterを必須とし、設定不足は明示エラー。
待ち合わせで観測された既知相手の名前呼び→音の方へ振り向く→視認相手へ接近を接続。
既存食事/身体/作業の優先は維持。声cueは既存の期限/再発話間隔を使う。
名前・外見を全員が知る初期教示は暫定固定。通常の発話選択として学習済みとは扱わない。
反応は同意ではなく注意。取引価値や世界の接触条件は従来どおり。

採用した範囲：焚火休息、視認した相手への接近、名前呼びと振り向き。
固定広場への強制誘導は不採用。見送りを声で伝える終話は未実装。
加工中等の優先行動があると応答は延期され、音cueが失効する場合がある。

## 条件

初期から人4体・10日・動物OFF。前回human-fire-rest-10-20261128の入力に
meeting_name_calls=trueと既存call_input.jsonの4人rosterを追加。
研修、栄養40、歩行消耗1%、食料再生、個人宅、倉庫非公開、取引を維持。
Julia1.13.1/1thread、凍結ソース・日末保存。
出力予定：C:/Users/ken_m/Documents/Codex/human-fire-name-calls-10-20261128。
名前呼び/振り向きはevents.methodとsocial_relationships.identity_observation.callsへ記録。
焚火休息、接触、提示、成立、身体、実時間を終了後に確認する。効果は未判定。

## 初回起動失敗と再実行

初回はday.jlの設定検査で未初期化camp_callsを参照し、初日開始前に終了コード1。
日末checkpoint・completed.jsonなし。接続テスト後に追加した検査行を再検証しないまま
長期起動したことが見逃しの原因。設定検査はspecを直接参照する形へ修正。
修正後の完全なソースでmeeting_call_lw_checks.jlを再実行してから再起動する。
初回出力は失敗証拠として保持。再実行先human-fire-name-calls-10-retry-20261128。

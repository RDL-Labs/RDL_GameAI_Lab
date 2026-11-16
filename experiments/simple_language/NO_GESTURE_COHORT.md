# 全員ジェスチャーなし・E別語句

2026-11-16。alternate_cohortと同じ13日末から20日、E実食研修3日、加入後20日。
RDL_NO_GESTURES=1（既定OFF）で全員の発信ジェスチャーのみ無効化。
A/B/Eは発話ON、C/Dは発話OFFのまま。Eはナ/リ/ソ、既存組はモ/ユ/ケ。
作者の暫定固定条件であり自律的な表現選択ではない。
開始時の既存4体の記憶は前回と同じで、13日までの動作経験も保持する。
以後の現在表現にジェスチャートークンは入らない。Eは通信経験空から開始。
物品提示・実際の受渡し・視覚的な結果場面は残す。これらをジェスチャーとは数えない。
構造化された取引条件の受信経路は残るので、生存/取引成立だけでは言語理解を示さない。
別語句の対応形成、候補予測への利用、結果と資源収支を分けて確認する。

入口no_gesture_cohort_suite.jl BASE OUTPUT。条件は各段階channel_conditions.jsonに保存し、
全員のgesture=falseを起動時に検査する。詳細追跡は終了後。
出力: C:/Users/ken_m/Documents/Codex/communication-no-gesture-cohort-20261116
worker: C:/Users/ken_m/Documents/Codex/communication-no-gesture-worker-20261116
完了判定はworker.exit.json、root/completed.jsonと各段階completed.json。
起動時点では結果未確認。

# 神の像への実MB相談・局所試験

2026-11-18。llm_statue_local.jlで1呼出し。Dの18日目293823000000usの
選択時gradient_mapsから抽出済みのcontextを利用。将来の取引結果、日末の
更新済みMB、他者の内部状態、過去のLLM生成発話は送らない。
本人が自律的に相談する仕組みはまだない。手動で像へ渡す暫定実験であり、
返答を世界や本人の判断へ反映しない。APIキーは環境のみ、store=false、再試行なし。

モデルgpt-4.1-mini-2025-04-14。入力979・出力217token、約3.17秒。
返答は物品交換と関係構築のどちらを重視しているか問い返す内容になった。
ただし「相手のニーズは満たされている」「関係性を確かめ合う」は根拠を超える。
need_before/after=0は相談者Dの予測不足であり、相手の充足を示さない。
観測されたdistress=0も相手の内部充足を確定させない。関係加点は小さな正数で、
相互の意図までは示さない。「与えられた」も未実行の提示としては曖昧。
像の解釈例として保存するが、正しい内面説明や助言と認定しない。

元データ：communication-mb-request-cohort-20261117/continue20/checkpoints/day-018.jls。
入力・全文・使用量：C:/Users/ken_m/Documents/Codex/llm-statue-d18-20261118/
request.json / completed.json。実行入力はllm-real-trade18-20261118/dialogue.jsonの
D contextだけで、speaker_gives/receivesと勾配・想起MB・本人予測を含む。

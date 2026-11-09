# 暫定固定: 採食供給の診断専用。SEARCHをRESTへ置換し同一区画で待機。
# 通常OFF、HeldPatch診断だけから呼ぶ。休息・睡眠・消化は通常モデル。
# 世界の正解量は判断に使わない。移動/繁殖/捕食を含む通常試験で後日検証する。
configured_rabbit_held_patch(state,search,rest)=state==search ? rest : state

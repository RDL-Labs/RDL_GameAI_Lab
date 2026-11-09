# 捕食者1体・獲物栄養半減

2026-11-09。捕食者数を増やす代わりに狩りの必要頻度を増やす比較条件。
成体栄養900×倍率0.75=675、基礎消費300/日で2.25日相当。
従来の倍率1.5（1350、4.5日相当）から半減。移動・回復消費・容量は変更なし。
幼体は既存の体格倍率がかかり、満腹で入り切らない分は従来どおり廃棄。

`crossing_longrun.jl`第16引数で倍率を指定（省略時1.5で旧実験互換）。
条件JSONにnutrition、adult_prey_energy、adult_prey_basal_daysを保存。
DONOR=noneで新規MBを選べるようにし、今回継承なし。
捕食者1体、population=fixed。流入出・死亡後の補充なし。
初期配置は既存の固定捕食者スポーン地点。過去ratio実験の境界出現とは異なるため、
その結果との直接比較では配置差も含む。栄養だけの比較には同じfixed配置を使う。

## 3日動作確認

入力は従来の `outputs/lw-rabbit-family-30d-20261106/input.json`。
人なし、兎100匹、草1.5、diverse/patchy/distributed/layered、泳ぎあり、CPU/GPU自動。
引数末尾：`3 true 1 1.5 none true auto diverse patchy distributed layered fixed 0.75`。
出力：`C:/Users/ken_m/Documents/Codex/predator-one-halfnutrition3d-20261109`。

終了コード0、completed.days=3、verified=true。
兎104（100+出生6-捕食2）、餓死0。捕食者生存、食料1179.018。
2捕獲の摂取合計1350、廃棄0で1匹675が実反映。
呼出し15.240秒、累積割当5.558GB、GC0.522秒。
短期の動作確認であり、狩り頻度・餓死リスク・処理負荷の長期効果は未検証。

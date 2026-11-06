# 休息先の想起幅は1。場所そのものは固定せず、候補生成ごとに共通MB評価で選ぶ。
# single_rest_place=falseなら全候補を渡す。場所記憶・経験・進行中試行は変更しない。
function configured_predator_rest_candidates!(mind,rows)
    PREDATOR_COGNITION.single_rest_place || return rows
    rest_rows=filter(c->c["action"]==:visit_rest,rows)
    isempty(rest_rows) && return rows
    rest_selected=rest_rows[argmax(LW.method_distribution(mind.loop,rest_rows))]
    filter!(c->c["action"]!=:visit_rest || c===rest_selected,rows)
    rows
end

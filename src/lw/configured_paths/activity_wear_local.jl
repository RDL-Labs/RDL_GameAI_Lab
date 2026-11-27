# 暫定固定・局所実験専用、通常LWへ未接続。
# 利益・作業1時間・帰路0.5時間を実験入力として渡す。地図の正解距離は読まない。
# 将来は各MBの利益・行程・修復見込みから候補を作る。
# 消耗は身体状態でありHではない。失敗学習や目的達成報酬は変更しない。
const ACTIVITY_WEAR_CHOICE=(cost_gain=4.,repair_gain=2.,)
function configured_activity_wear_candidates(wear,work_hours,return_hours;
        effort=1.,benefit=1.,repair_hours=8.,rules=ACTIVITY_WEAR_CHOICE)
    work=ActivityWear.RULES.walk_per_hour*effort*work_hours
    returning=ActivityWear.RULES.walk_per_hour*effort*return_hours
    after_return=wear+returning
    after_work_return=after_return+work
    recovery=min(after_return,ActivityWear.RULES.sleep_per_hour*repair_hours)
    # Repair relief versus foregone task benefit. Square pressure grows with wear;
    # adding another identical walk becomes less attractive later in the day.
    choices=Any[D("method"=>"continue","priority"=>benefit-rules.cost_gain*after_work_return^2),
        D("method"=>"home","priority"=>rules.repair_gain*recovery-rules.cost_gain*after_return^2)]
    for choice in choices;choice["question"]="activity_recovery";end
    # Physical impossibility, distinct from a preference to finish today's work.
    after_work_return>=1 && filter!(c->c["method"]!="continue",choices)
    choices
end

# 暫定固定・局所専用: 将来の作業/帰路見積もりを入力する。
# 比率1以上は身体限界として候補を制限する。容量低下で疲労量は切り捨てない。
# 帰宅不能ならその場の休息。地形安全性・緊急性の比較はまだ含まない。
const ACTIVITY_CAPACITY_CHOICE=(fatigue_cost_gain=2.,)
function configured_activity_capacity_candidates(body,work_hours,return_hours;
        effort=1.,benefit=1.,repair_hours=8.)
    prediction=ActivityCapacity.forecast(body,work_hours,return_hours;effort)
    if ActivityCapacity.ratio(prediction.home)>=1
        return Any[D("method"=>"rest_here","priority"=>0.,"question"=>"activity_recovery")]
    end
    choices=configured_activity_wear_candidates(body.physical.wear,work_hours,return_hours;effort,benefit,repair_hours)
    filter!(c->c["method"]!="continue" || ActivityCapacity.ratio(prediction.work_home)<1,choices)
    for choice in choices
        predicted=choice["method"]=="home" ? prediction.home : prediction.work_home
        choice["priority"]-=ACTIVITY_CAPACITY_CHOICE.fatigue_cost_gain*ActivityCapacity.ratio(predicted)^2
    end
    choices
end

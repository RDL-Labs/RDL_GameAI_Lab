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

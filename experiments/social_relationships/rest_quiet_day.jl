# 暫定固定・速度診断のみ。選択済み休息中は動体通知で通常認知へ戻さない。
# REST_QUIET_ENABLED is false in the comparison baseline; no production default change.
# Body/time/review/communication/pending-result checks remain in task_focus_continue!.
# Future replacement: learned attention based on safety, uncertainty, and interruption value.
function rest_quiet_overlay(source)
    before="notice=get(fs,\"active\",false) && focus_enabled ? task_motion_notice"
    count(before,source)==1 || error("rest motion anchor")
    replace(source,before=>"notice=get(fs,\"active\",false) && focus_enabled && !(REST_QUIET_ENABLED[] && fs[\"plan\"][\"action\"]==\"rest\") ? task_motion_notice")
end
rest_quiet_driver_path=joinpath(@__DIR__,"benchmark_recognition_reuse.jl")
rest_quiet_source=read(rest_quiet_driver_path,String)
rest_quiet_source=replace(rest_quiet_source,
    "include(\"recognition_fit_workspace.jl\")\nfit_trial_install!(FIT_BENCH_ROOT)"=>"const REST_QUIET_ENABLED=Ref(false)",
    "include(\"recognition_fit_workspace.jl\")\r\nfit_trial_install!(FIT_BENCH_ROOT)"=>"const REST_QUIET_ENABLED=Ref(false)")
occursin("fit_trial_install!",rest_quiet_source) && error("cache removal anchor")
rest_quiet_source=replace(rest_quiet_source,"FIT_TRIAL_ENABLED"=>"REST_QUIET_ENABLED","empty!(FIT_TRIAL_WORKSPACES);"=>"")
rest_quiet_source=replace(rest_quiet_source,"Base.include_string(Main,fit_bench_source,fit_bench_file)"=>"fit_bench_source=rest_quiet_overlay(fit_bench_source)\nBase.include_string(Main,fit_bench_source,fit_bench_file)")
rest_quiet_source=replace(rest_quiet_source,"@test isempty(FIT_BENCH_DIFFS)"=>"@test Set(keys(fit_bench_before))==Set(keys(fit_bench_after))")
rest_quiet_source=replace(rest_quiet_source,"fit_bench_compare(fit_bench_before,fit_bench_after,\"state\")"=>"push!(FIT_BENCH_DIFFS,\"Not compared: behavioral intervention; see activity.json\")")
rest_quiet_source=replace(rest_quiet_source,"checkpoint_fields_equal=true"=>"checkpoint_fields_equal=nothing")
rest_quiet_source=replace(rest_quiet_source,"recursive field-value comparison, including stored RNG; alias topology not compared"=>"Only checkpoint field names checked; behavior intentionally changed, no state equality claim")
rest_quiet_source=replace(rest_quiet_source,"joinpath(@__DIR__,\"recognition_fit_workspace.jl\")"=>"joinpath(@__DIR__,\"rest_quiet_day.jl\")")
Base.include_string(Main,rest_quiet_source,rest_quiet_driver_path)
rest_quiet_prior=deserialize(FIT_BENCH_CHECKPOINT).state
rest_quiet_rows=Any[]
for (label,state) in (("before",fit_bench_before),("after",fit_bench_after)), actor in IDS
    task=state[:mb_maps][actor]["task_focus"];prior_task=rest_quiet_prior[:mb_maps][actor]["task_focus"]
    push!(rest_quiet_rows,(label=label,actor=actor,
        actions=Dict(k=>v-get(rest_quiet_prior[:counts][actor],k,0) for (k,v) in state[:counts][actor]),
        observations=state[:mb_maps][actor]["observations"]-rest_quiet_prior[:mb_maps][actor]["observations"],
        focus_skipped=task["skipped"]-prior_task["skipped"],
        wakeups=Dict(k=>v-get(prior_task["wakeups"],k,0) for (k,v) in task["wakeups"]),
        physical=state[:daily][end]["physical"][actor]))
end
write(joinpath(FIT_BENCH_OUT,"activity.json"),JSON3.write(rest_quiet_rows))
write(joinpath(FIT_BENCH_OUT,"condition.json"),JSON3.write((rule="rest motion notices suppressed; existing review/body/communication gates retained",behavior_changes_expected=true)))

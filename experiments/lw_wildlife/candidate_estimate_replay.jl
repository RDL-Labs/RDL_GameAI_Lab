# Reuse identical checkpoint/day timing and cognition instrumentation.
# Modes: audit or paired. In paired output, "merged" means candidate reuse.
const candidate_mode=ARGS[4]
candidate_mode in ("audit","paired") || error("candidate mode")
ARGS[4]=candidate_mode=="audit" ? "baseline" : "paired"
driver=read(joinpath(@__DIR__,"return_validation_replay.jl"),String)
first_section=findfirst("if replay_mode==\"audit\"",driver).start
end_section=findfirst("struct ReplayDone",driver).start
replacement=candidate_mode=="audit" ? "include(joinpath(@__DIR__,\"candidate_estimate_audit.jl\"))\n" : """
parent_source=read(joinpath(replay_root,"source/src/lw/learning/mb_parent.jl"),String)
old_part="function mb_parent_candidates!"*first(split(last(split(parent_source,"function mb_parent_candidates!")),"function mb_parent_begin!"))
Base.include_string(LW,replace(old_part,"mb_parent_candidates!("=>"mb_parent_candidates_baseline!("))
new_source=read(joinpath(@__DIR__,"../../src/lw/learning/mb_parent.jl"),String)
new_part="function mb_parent_candidates!"*first(split(last(split(new_source,"function mb_parent_candidates!")),"function mb_parent_begin!"))
write(joinpath(replay_out,"candidate_overlay.jl"),new_part)
Base.include_string(LW,replace(new_part,"mb_parent_candidates!("=>"mb_parent_candidates_optimized!("))
Base.include_string(LW,"mb_parent_candidates!(s,candidates,goal,target)=Main.replay_merge[] ? mb_parent_candidates_optimized!(s,candidates,goal,target) : mb_parent_candidates_baseline!(s,candidates,goal,target)")
"""
driver=driver[1:first_section-1]*replacement*driver[end_section:end]
# Audit also gets a complete day warmup; measurements use a fresh load.
driver=replace(driver,"replay_warm[] && replay_mode!=\"paired\" && replay_ticks[]>512"=>"false")
if candidate_mode=="audit"
    driver=replace(driver,"println(\"REPLAY \""=>"empty!(candidate_stats);empty!(candidate_fixtures);println(\"REPLAY \"")
    driver=replace(driver,"validation=copy(validation_stats)"=>"validation=copy(candidate_stats)")
    driver*= "\nserialize(joinpath(replay_out,\"candidate-fixtures.jls\"),candidate_fixtures)\n"
end
Base.include_string(Main,driver,joinpath(@__DIR__,"candidate_driver.jl"))

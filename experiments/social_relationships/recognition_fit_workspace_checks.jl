using Test
include(joinpath(ARGS[1],"source/integrations/lightweight_julia/native.jl"))
include("recognition_fit_workspace.jl")
fit_trial_install!(ARGS[1])
@testset "derived same-judgment fit workspace" begin
    s=mb_map_state("test")
    signature="brown:far:0|gray:near:1"
    frame=(key="here",signature=signature,anchor=17.,features=mb_features(signature))
    s["current"]=frame;s["current_us"]=1
    s["nodes"]["known"]=D("signature"=>"brown:mid:0|gray:near:1")
    s["nodes"]["unknown"]=D("signature"=>"blue:far:0")
    reference=deepcopy(s);trial=deepcopy(s)
    for scope in ("goal_cue","outbound_home","chunk","sleep"), H in (0.,8.)
        FIT_TRIAL_ENABLED[]=false
        expected=mb_correspondences(reference,["known","unknown"],1;scope,H,ordered_targets=["unknown","known"])
        FIT_TRIAL_ENABLED[]=true
        actual=mb_correspondences(trial,["known","unknown"],1;scope,H,ordered_targets=["unknown","known"])
        @test actual==expected
    end
    @test trial==reference # Includes recognition counters; no cache stored here.
    work=fit_trial_workspace(trial,trial["current"],1)
    @test length(work.entries)==2
    @test work.entries["unknown"].fit===nothing
    @test fit_trial_workspace(trial,trial["current"],1)===work
    trial["recognition"]["metric"]["weights"][1]=3.
    @test fit_trial_workspace(trial,trial["current"],1)!==work
    work=fit_trial_workspace(trial,trial["current"],1)
    @test fit_trial_workspace(trial,trial["current"],2)!==work
    shifted=merge(trial["current"],(anchor=45.,))
    @test fit_trial_workspace(trial,shifted,2).frame===shifted
    work=fit_trial_workspace(trial,shifted,2)
    metric=trial["recognition"]["metric"]
    fit_trial_similarity(work,"known",shifted,trial["nodes"]["known"],metric)
    trial["nodes"]["known"]=D("signature"=>"brown:near:0|gray:far:2")
    actual=fit_trial_similarity(work,"known",shifted,trial["nodes"]["known"],metric)
    raw=mb_similarity(shifted,trial["nodes"]["known"];metric)
    @test actual==(confidence=raw.confidence,anchor=raw.anchor)
    @test !hasproperty(actual,:parts)
    # Workspace is rebuilt from restored persistent state, not carried across runs.
    empty!(FIT_TRIAL_WORKSPACES)
    @test isempty(fit_trial_workspace(deepcopy(trial),shifted,2).entries)
end

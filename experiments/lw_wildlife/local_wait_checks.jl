function local_wait_fixture()
    s,ps=animal_trial_world();p=ps[1];p.mode=:hunt
    state=LocalHunt(1)
    state.selected=LW.choose_method!(state.loop,[LW.D("method"=>"wait","question"=>"capture_opportunity","priority"=>0.,"speed"=>0.)],1)
    state.wait_trial=LW.action_trial(1,"wait","capture_opportunity",LOCAL_HUNT.wait_forecast_ticks)
    state.wait_target=1;state.wait_spent=p.spent;state.loop.H=3.
    s,p,state
end
function local_wait_checks()
    @testset "wait child lifecycle" begin
        s,p,state=local_wait_fixture();trial=state.wait_trial
        for i in 1:LOCAL_HUNT.wait_forecast_ticks-1
            p.spent+=.1;configured_local_hunt_finish!(state,p)
        end
        @test state.wait_trial===trial && trial["elapsed"]==19
        @test state.loop.sequence==1 && state.loop.H==3.
        p.spent+=.1;configured_local_hunt_finish!(state,p)
        @test state.wait_trial===nothing && state.selected===nothing
        @test state.loop.methods["wait"].H>0 && state.loop.H==3.
        @test state.wait_records[end].status=="failed" && state.wait_records[end].trial["energy"]≈2.
        s,p,state=local_wait_fixture()
        configured_local_wait_close!(state,"achieved","capture_opportunity_observed")
        @test state.loop.H==3. && state.loop.methods["wait"].reward==0
        @test p.visual.body.captures==0
        s,p,state=local_wait_fixture();p.mode=:rest
        configured_local_hunt_finish!(state,p)
        @test state.wait_records[end].status=="interrupted" && state.loop.trial===nothing
        @test state.loop.H==3.
    end
end

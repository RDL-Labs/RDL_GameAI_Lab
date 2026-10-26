include("mb_recognition_checks.jl")
@testset "experience updates the similarity criterion" begin
 m=mb_metric_state();initial=copy(m["weights"])
 for i in 1:100;mb_metric_update!(m,[(1.,0.)],1.,"positive:$i");end
 @test m["weights"][1]<initial[1] && m["weights"][2]==initial[2]
 for i in 1:100;mb_metric_update!(m,[(0.,1.)],0.,"negative:$i");end
 @test m["weights"][2]>initial[2]
 @test all(.25 .<= m["weights"] .<= 4.)
 @test length(m["records"])==64 && m["positive"]==100 && m["negative"]==100
 frame=mb_scene(recognition_view(0,"mid"));node=D("signature"=>mb_scene(recognition_view(0,"far")).signature)
 fixed=mb_similarity(frame,node).agreement
 @test mb_similarity(frame,node;metric=m).agreement>fixed
 m["enabled"]=false;before=deepcopy(m)
 mb_metric_update!(m,[(1.,1.)],1.,"disabled")
 @test m==before && mb_similarity(frame,node;metric=m).agreement==fixed
 # Actual observation/receipt pipeline learns without first selecting an MB route.
 s=recognized_trip();metric=s["recognition"]["metric"]
 @test metric["updates"]>0 && s["recognition"]["selected"]==0
 @test s["sensitivity"]==mb_sensitivity()
 # Blocked actions cannot train a negative appearance label.
 count=metric["updates"];weights=copy(metric["weights"])
 mb_record!(s,walk,"blocked",0.,2_000_000)
 mb_observe!(s,recognition_view(3_000_000),3_000_000)
 @test metric["updates"]==count && metric["weights"]==weights
 # Missing next observation and a time gap also cannot train.
 mb_record!(s,walk,"performed",0.,3_000_000)
 emptyview=D("source"=>"ob:4000000:a","features"=>Any[],"coverage"=>"partial")
 mb_observe!(s,emptyview,4_000_000)
 @test metric["updates"]==count
 @test length(metric["examples"])<=64
 # Evaluation is fixed even when learned weights change: no self-labeling.
 s=recognized_trip();key=first(keys(s["edges"]))
 receipt=D("now"=>0,"status"=>"performed","predicted"=>key)
 f=mb_scene(recognition_view(1_000_000,"near"))
 outcome=mb_prediction_outcome(s,receipt,f,1_000_000)
 s["recognition"]["metric"]["weights"].=.25
 @test mb_prediction_outcome(s,receipt,f,1_000_000)==outcome
end

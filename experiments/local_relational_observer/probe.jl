using Test
check(ok, message) = ok || error(message)
include("../../src/lw/decision/basic_loop.jl")
include("../../src/lw/decision/relational_gradient.jl")

# 人工MBによる局所試作。本体未接続。値は実測・学習済みデータではない。
# 通常のBasicLoopを使うが、方法H・失敗履歴は今回の独立変数に含めない。
const PROBE_RULES = (tolerance=0.1, sensitivity=1.0, high_H=8.0,
    initial_count=1, expanded_count=2, seed=22)
struct ProbeMB
    id::Symbol
    goal::Symbol
    strength::Float64
    coarse::Float64
    fine::Float64
    cost::Float64
    unresolved::Vector{Symbol}
end
mutable struct LocalView
    goal::Symbol
    boundary::Vector{Symbol}
    resolution::Symbol
    H::Float64
    evidence::Set{Symbol}
end
function recall(memory, goal, count)
    related=filter(m->m.goal==goal,memory)
    sort!(related;by=m->(-m.strength,string(m.id)))
    [m.id for m in Iterators.take(related,count)]
end
function observe_local(memory, view)
    view.resolution in (:coarse,:fine) || error("unknown resolution")
    length(unique(view.boundary))==length(view.boundary) || error("duplicate MB")
    rows=Dict{String,Any}[]; open_xi=Symbol[]
    for id in view.boundary
        index=findfirst(m->m.id==id,memory)
        index===nothing && error("invalid MB reference")
        mb=memory[index]
        mb.goal==view.goal || error("wrong goal binding")
        benefit=view.resolution==:fine ? mb.fine : mb.coarse
        field=relational_transition(0.,benefit;cost=mb.cost)
        push!(rows,Dict("method"=>string(id),"priority"=>field.expected))
        append!(open_xi,mb.unresolved)
    end
    loop=BasicLoop(string(view.goal);probabilistic=true,seed=PROBE_RULES.seed)
    loop.H=view.H
    (rows=rows, probabilities=method_distribution(loop,rows), xi=unique(open_xi))
end
function record_residual!(view, owner, receipt, residual)
    owner==view.goal || return false # 子の証拠で別の親を解消しない。
    receipt in view.evidence && return false
    push!(view.evidence,receipt)
    # 試作では「現在の未解消差」の証拠で置換する。単純な毎tick加算ではない。
    # 未観測は更新保留。ξの存在だけではHを増やさない。
    residual===nothing && return false
    isfinite(residual) && residual>=0 || error("invalid residual")
    view.H=PROBE_RULES.sensitivity*max(0.,residual-PROBE_RULES.tolerance)
    true
end
function investigation_choices(H, expectations)
    loop=BasicLoop("investigate";probabilistic=true,seed=PROBE_RULES.seed);loop.H=H
    rows=[Dict{String,Any}("method"=>string(e.action),"priority"=>
        relational_transition(0.,e.relief;cost=e.cost).expected) for e in expectations]
    (actions=[e.action for e in expectations], probabilities=method_distribution(loop,rows))
end

function run_probe()
    # 拠点経路の粗い見込みと、細部を観測した見込み。値は合成fixture。
    memory=[ProbeMB(:familiar_route,:home,0.9,4.,0.2,0.1,[:unseen_gap]),
        ProbeMB(:alternative_route,:home,0.6,1.,2.,0.1,Symbol[]),
        ProbeMB(:food_site,:food,0.95,5.,5.,0.1,Symbol[])]
    view=LocalView(:home,recall(memory,:home,2),:coarse,0.,Set{Symbol}())
    low=observe_local(memory,view)
    view.H=PROBE_RULES.high_H; high=observe_local(memory,view)
    view.resolution=:fine; fine=observe_local(memory,view)
    view.resolution=:coarse; view.boundary=recall(memory,:home,PROBE_RULES.initial_count)
    narrow=observe_local(memory,view)
    view.boundary=recall(memory,:home,PROBE_RULES.expanded_count)
    broad=observe_local(memory,view)
    # 同じHでも、確認で解消できるという見込みが異なれば選ばれ方が変わる。
    detail=investigation_choices(view.H,[(action=:refine,relief=3.,cost=.2),
        (action=:coarsen,relief=.2,cost=.1),(action=:widen,relief=1.,cost=.3)])
    overview=investigation_choices(view.H,[(action=:refine,relief=.2,cost=.2),
        (action=:coarsen,relief=3.,cost=.1),(action=:widen,relief=1.,cost=.3)])
    @testset "H / resolution / boundary separation" begin
        @test low.rows==high.rows
        @test high.probabilities[1]<low.probabilities[1]
        @test high.probabilities[2]>low.probabilities[2]
        @test fine.rows!=high.rows
        @test fine.probabilities[2]>fine.probabilities[1]
        @test length(narrow.rows)==1
        @test narrow.probabilities==[1.]
        @test :unseen_gap in narrow.xi # 確率1は完全整合ではない。
        @test length(broad.rows)==2
        @test view.H==PROBE_RULES.high_H
        @test all(r->r["method"]!="food_site",broad.rows)
        @test detail.actions[argmax(detail.probabilities)]==:refine
        @test overview.actions[argmax(overview.probabilities)]==:coarsen
        @test all(>(0.),detail.probabilities) # 特定の確認行動を強制しない。
        @test !record_residual!(view,:food,:child_success,0.)
        @test view.H==PROBE_RULES.high_H
        @test !record_residual!(view,:home,:missing,nothing)
        @test view.H==PROBE_RULES.high_H
        @test record_residual!(view,:home,:stalled,2.1)
        @test view.H≈2.
        @test !record_residual!(view,:home,:stalled,0.)
        @test view.H≈2.
        @test record_residual!(view,:home,:resolved,.05)
        @test view.H==0.
        @test_throws ErrorException observe_local(memory,LocalView(:home,[:missing],:coarse,0.,Set{Symbol}()))
    end
    report=["# 局所H・ρ・境界試験", "", "人工MB、既存BasicLoop/relational_transition使用。本体・長期実験への接続なし。", "",
        "| 条件 | 候補 | 選択確率 |", "|---|---|---|"]
    for (label,result) in [("粗いρ / H=0",low),("粗いρ / H=8",high),("細かいρ / H=8",fine),
        ("境界1件 / H=8",narrow),("境界2件 / H=8",broad)]
        candidate_names=join([r["method"] for r in result.rows], ", ")
        probability_text=join(round.(result.probabilities;digits=6), ", ")
        push!(report,"| $label | $candidate_names | $probability_text |")
    end
    push!(report,"", "確認候補順: refine / coarsen / widen",
        "", "細部確認が有望: $(round.(detail.probabilities;digits=6))",
        "", "全体把握が有望: $(round.(overview.probabilities;digits=6))",
        "", "確率分布の比較であり、行動の連続実行・見込みの学習・実際の帰還改善は未検証。")
    write(joinpath(@__DIR__,"result.md"),join(report,"\n")*"\n")
end
run_probe()

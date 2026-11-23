using Test
include("forecast_difference.jl")
using .ForecastDifferenceProbe
# 本体未接続の合成試験。成果は個数、forecastは1個あたりの活動秒。
const HIERARCHY_PROBE=(penalty_gain=1.,temperature=1.)
mutable struct PurposeProbe
    id::Symbol
    forecast::Float64
    elapsed::Float64
    expected::Float64
    acquired::Float64
    H::Float64
    closed::Bool
    receipts::Set{Int}
    difference::ForecastDifference
end
function PurposeProbe(id,forecast)
    isfinite(forecast) && forecast>0 || error("invalid forecast")
    PurposeProbe(id,forecast,0.,0.,0.,0.,false,Set{Int}(),ForecastDifference())
end
function observe_outcome!(mb,receipt,seconds,acquired)
    mb.closed && return false
    receipt in mb.receipts && return false
    all(x->isfinite(x)&&x>=0,(seconds,acquired)) || error("invalid outcome")
    acquired isa Bool && error("outcome must be quantity")
    observe_difference!(mb.difference,receipt,seconds/mb.forecast,acquired)
    push!(mb.receipts,receipt)
    mb.elapsed+=seconds
    mb.expected+=seconds/mb.forecast
    mb.acquired+=acquired
    # 未解消量を毎回加算しない。見込み・成果の台帳から現在の不足を計算。
    # 同じ活動の成果を親子が独立評価する。子Hは親の入力ではない。
    mb.H=residual_h(mb.difference)
    true
end
function local_probabilities(base,mbs)
    score=[b-HIERARCHY_PROBE.penalty_gain*m.H for (b,m) in zip(base,mbs)]
    weights=exp.((score.-maximum(score))/HIERARCHY_PROBE.temperature)
    weights/sum(weights)
end
function run_hierarchy_probe()
    fishing=PurposeProbe(:fishing,180.)
    gathering=PurposeProbe(:gathering,180.)
    site_a=PurposeProbe(:site_a,90.)
    site_b=PurposeProbe(:site_b,180.)
    report=["# 見込み成果との差を蓄積する親子H", "",
      "人工MB。親は180活動秒で1匹、Aは90秒、Bは180秒で1匹の線形期待。",
      "連続的な期待量であり、最初の1匹の期限までH=0とする方式ではない。", "",
      "| 段階 | 親の見込み | 実績 | 親H | AのH | BのH | 釣り確率% |",
      "|---|---:|---:|---:|---:|---:|---:|"]
    function record(label)
        p=local_probabilities([1.,0.],[fishing,gathering])
        push!(report,"| $label | $(fishing.expected) | $(fishing.acquired) | $(fishing.H) | $(site_a.H) | $(site_b.H) | $(round(100p[1];digits=2)) |")
        p
    end
    record("開始")
    @testset "cumulative expected minus acquired" begin
        observe_outcome!(site_a,1,180.,0.)
        observe_outcome!(fishing,1,180.,0.)
        record("Aで180秒・0匹")
        @test site_a.H==2.
        @test fishing.H==1.
        observe_outcome!(site_b,2,180.,0.)
        observe_outcome!(fishing,2,180.,0.)
        p0=record("Bへ移動・さらに180秒・0匹")
        @test fishing.expected==2.
        @test fishing.H==2.
        @test site_a.H==2.
        @test site_b.H==1.
        # 同じ時点で捕獲を受領。経過を再加算しない。
        observe_outcome!(site_b,3,0.,1.)
        observe_outcome!(fishing,3,0.,1.)
        p1=record("Bで1匹獲得・親の不足は1匹分残る")
        @test site_b.H==0.
        @test fishing.H==1.
        @test site_a.H==2.
        @test p1[1]>p0[1]
        @test !observe_outcome!(fishing,3,0.,1.)
        @test fishing.acquired==1.
        observe_outcome!(fishing,4,0.,0.)
        @test fishing.H==1. # 再観測だけでは不足を二重加算しない。
        observe_outcome!(site_b,5,180.,1.)
        observe_outcome!(fishing,5,180.,1.)
        record("180秒でさらに1匹・見込みも1匹増え不足維持")
        @test fishing.expected==3.
        @test fishing.acquired==2.
        @test fishing.H==1.
        observe_outcome!(site_b,6,0.,1.)
        observe_outcome!(fishing,6,0.,1.)
        record("同時点の追加1匹で不足解消")
        @test fishing.H==0.
        @test site_a.H==2.
        @test !fishing.closed # 一回の成功では閉じない。
        child=local_probabilities([1.,0.],[site_a,site_b])
        observe_outcome!(fishing,7,180.,0.)
        @test fishing.H==1.
        @test local_probabilities([1.,0.],[site_a,site_b])==child
        fishing.closed=true
        @test !observe_outcome!(fishing,8,180.,0.)
        @test fishing.expected==4.
        @test_throws ErrorException PurposeProbe(:invalid,0.)
        # 時間の分割によって同じ総投入・成果のHが変わらない。
        split=PurposeProbe(:split,180.);whole=PurposeProbe(:whole,180.)
        for i in 1:4;observe_outcome!(split,i,90.,i==4 ? 1. : 0.);end
        observe_outcome!(whole,1,360.,1.)
        @test split.H==whole.H==1.
        @test_throws ErrorException observe_outcome!(whole,2,-1.,0.)
        @test !(2 in whole.receipts)
    end
    push!(report,"", "場所変更・成果は外部から与えた条件。行動の自律選択・学習は未検証。",
      "見込みは活動時間に比例して増加。休止中の時間はこの試験では加えない。",
      "同一エピソードの先行成果は台帳に残るため、後の不足を相殺する。",
      "達成で閉じるか、方法の持続評価として継続するかは別操作。予測更新・新エピソードへの引継ぎは未接続。")
    write(joinpath(@__DIR__,"hierarchy_h_penalty_result.md"),join(report,"\n")*"\n")
end
run_hierarchy_probe()

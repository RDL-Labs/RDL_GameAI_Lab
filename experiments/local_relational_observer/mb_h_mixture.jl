using Test

# 本体未接続の局所仮説。h0は反応が半分となる局所H、thetaは共通評価尺度。
# 合成MBの不一致コストを入力する。実個体の学習・再観測を実装したものではない。
const MIXTURE_RULES=(h0=2.,theta=1.)
function reconsider_fraction(H;h0=MIXTURE_RULES.h0)
    isfinite(H) && H>=0 && isfinite(h0) && h0>0 || error("invalid H scale")
    H==0 && return 0.
    H<=h0 ? (H/h0)^2/(1+(H/h0)^2) : 1/(1+(h0/H)^2)
end
function mb_mixture(experience_cost,reconsider_cost,local_H;theta=MIXTURE_RULES.theta)
    length(experience_cost)==length(reconsider_cost)==length(local_H) || error("binding")
    isempty(local_H) && return (weights=Float64[],probabilities=Float64[],fractions=Float64[])
    isfinite(theta) && theta>0 || error("invalid theta")
    all(x->isfinite(x)&&x>=0,experience_cost) || error("invalid cost")
    all(x->x===nothing || (isfinite(x)&&x>=0),reconsider_cost) || error("invalid review")
    fractions=[reconsider_fraction(h) for h in local_H]
    # 同じ尺度・同じ境界のコストだけを比較する。枝ごとの別正規化はしない。
    logweights=map(eachindex(local_H)) do i
        old=-experience_cost[i]/theta
        new=reconsider_cost[i]===nothing ? old : -reconsider_cost[i]/theta
        alpha=fractions[i];scale=max(old,new)
        scale+log((1-alpha)*exp(old-scale)+alpha*exp(new-scale))
    end
    weights=exp.(logweights)
    scaled=exp.(logweights.-maximum(logweights))
    (weights=weights,probabilities=scaled/sum(scaled),fractions=fractions)
end

function probe_mixture()
    # 「慣れた釣り・採取・探索」の人工MB。再検討で釣りの見込みだけ悪化する条件。
    experience=[0.2,1.,2.];review=[3.,1.,2.]
    low=mb_mixture(experience,review,[0.,0.,0.])
    high=mb_mixture(experience,review,[8.,0.,0.])
    missing=mb_mixture(experience,[nothing,nothing,nothing],[8.,0.,0.])
    unchanged=mb_mixture(experience,experience,[8.,0.,0.])
    positive=mb_mixture(experience,[0.,1.,2.],[8.,0.,0.])
    traditional(H)=begin
        w=exp.(-experience/(1+H/2));w/sum(w)
    end
    @testset "candidate-local H mixture" begin
        @test reconsider_fraction(0.)==0
        @test reconsider_fraction(2.)==.5
        @test reconsider_fraction(8.)≈16/17
        @test reconsider_fraction(floatmax(Float64))≈1
        @test_throws ErrorException reconsider_fraction(-1.)
        @test high.probabilities[1]<low.probabilities[1]
        @test high.weights[2:3]==low.weights[2:3]
        @test high.probabilities[2]/high.probabilities[3]≈low.probabilities[2]/low.probabilities[3]
        @test unchanged.probabilities≈low.probabilities
        @test missing.probabilities≈low.probabilities
        @test positive.probabilities[1]>low.probabilities[1]
        @test sum(high.probabilities)≈1
        @test all(isfinite,mb_mixture([10000.,10001.],[10002.,10001.],[8.,0.]).probabilities)
        @test isempty(mb_mixture(Float64[],Float64[],Float64[]).probabilities)
        @test_throws ErrorException mb_mixture([0.],[0.,1.],[0.])
        @test_throws ErrorException mb_mixture([NaN],[0.],[0.])
    end
    report=["# 候補MBごとのH混合：局所試験", "", "候補順：慣れた釣り / 採取 / 探索。合成コスト、実ログ再生ではない。", "",
      "| 条件 | 釣り | 採取 | 探索 |", "|---|---:|---:|---:|"]
    for (name,p) in [("低H",low.probabilities),("従来型の全体温度H=8",traditional(8.)),
        ("釣りH=8・再検討で悪化",high.probabilities),("釣りH=8・新情報なし",missing.probabilities),
        ("釣りH=8・再検討で改善",positive.probabilities)]
        push!(report,"| $name | "*join(round.(100p;digits=2)," | ")*" |")
    end
    push!(report,"", "16項目PASS。Hはそれ自体で減点せず、再検討結果の採用割合だけを変える。",
      "他MBの非正規化重み・相互の比率は不変。ただし全体正規化により各確率は変わる。",
      "新情報なしでは高Hでも選択は変わらない。未呼出し候補の生成や停滞脱出を保証しない。",
      "再検討値を正しく生成する仕組み・学習・Bの連続行動試験は未実装。")
    write(joinpath(@__DIR__,"mb_h_mixture_result.md"),join(report,"\n")*"\n")
end
probe_mixture()

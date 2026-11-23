using Test
include("forecast_difference.jl")
using .ForecastDifferenceProbe

# 暫定固定の合成入力。個体の見込み生成・ρ・身体・実釣には未接続。
# 値は「満たされる見込み」の比較用尺度。匹数や世界の真の捕獲確率ではない。
function run_fishing_difference_checks()
    parent = ForecastDifference()
    site_a = ForecastDifference()
    site_b = ForecastDifference()
    report = ["# 釣り：親子共通の見込み差H", "",
        "人工的な主観尺度による局所試験。本体・実釣ログには未接続。",
        "親と子で同じ更新関数を使用。子Hを親へ転送しない。", "",
        "| 状況 | 親H | 釣り場AのH | 釣り場BのH |",
        "|---|---:|---:|---:|"]
    record(label) = push!(report, "| $label | $(round(residual_h(parent);digits=3)) | $(round(residual_h(site_a);digits=3)) | $(round(residual_h(site_b);digits=3)) |")
    @testset "shared MB forecast difference" begin
        @test observe_difference!(parent, 1, .8, 0.)
        @test observe_difference!(site_a, 1, .3, 0.)
        record("見込みに対して成果なし")
        @test residual_h(parent) ≈ .8
        @test residual_h(site_a) ≈ .3
        # 同じ捕獲を、それぞれ自身の目的に対する成果として評価。
        @test observe_difference!(parent, 2, 0., .3)
        @test observe_difference!(site_a, 2, 0., .3)
        record("１匹獲得：子の見込みは満たすが親には差が残る")
        @test residual_h(parent) ≈ .5
        @test residual_h(site_a) == 0.
        @test !observe_difference!(parent, 2, 0., .3)
        @test residual_h(parent) ≈ .5
        @test !observe_difference!(parent, 3, .2, nothing)
        @test !(3 in parent.receipts)
        @test residual_h(parent) ≈ .5
        # 場所を変えても親の台帳は保持。未観測だった入力を後から確定。
        @test observe_difference!(parent, 3, .2, 0.)
        @test observe_difference!(site_b, 3, .1, 0.)
        record("場所変更後も成果なし")
        @test residual_h(parent) ≈ .7
        @test residual_h(site_b) ≈ .1
        @test residual_h(site_a) == 0.
        @test observe_difference!(parent, 4, 0., .4)
        @test observe_difference!(site_b, 4, 0., .1)
        record("追加成果：親の差は縮むが残る")
        @test residual_h(parent) ≈ .3
        @test residual_h(site_b) == 0.
        observe_difference!(parent, 5, 0., .5)
        @test residual_h(parent) == 0.
        @test parent.observed > parent.expected # 良い差は記録するが負のHにはしない。
        record("親の見込みも満たす")
        whole = ForecastDifference(); split = ForecastDifference()
        observe_difference!(whole, 1, 1., .5)
        observe_difference!(split, 1, .5, .25)
        observe_difference!(split, 2, .5, .25)
        @test residual_h(whole) == residual_h(split)
        @test_throws ArgumentError observe_difference!(whole, 2, NaN, 0.)
        @test_throws ArgumentError observe_difference!(whole, 2, 0., true)
        @test !(2 in whole.receipts)
    end
    push!(report, "", "Hは累積見込みと累積観測との差から算出し、残差そのものを毎回加算しない。",
        "見込み生成・観測の尺度化・許容幅・ρ・学習は未実装。今回の値はそれらの性能を示さない。",
        "この局所案では不足側をHにする。上振れは台帳に残すが報酬へは未接続。",
        "旧匹数試験も同じ共通関数を経由し、Hによるsoftmax減点と親子独立性を検査する。")
    write(joinpath(@__DIR__, "fishing_forecast_difference_result.md"), join(report, "\n") * "\n")
end
run_fishing_difference_checks()

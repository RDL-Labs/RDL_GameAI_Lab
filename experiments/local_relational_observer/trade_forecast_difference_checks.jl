using Test
include("forecast_difference.jl")
using .ForecastDifferenceProbe

# 暫定固定の合成入力。目的充足の主観評価を外から与える局所試験。
# 取引の成立判定・在庫移動・身体評価・自律交渉は実行しない。
# 成立した事実だけでHを消さず、各当事者・各MBの見込みと成果を照合する。
function run_trade_difference_checks()
    a_food = ForecastDifference()
    a_trade = ForecastDifference()
    a_partner_b = ForecastDifference()
    a_partner_c = ForecastDifference()
    b_trade = ForecastDifference()
    report = ["# 取引：親子共通の見込み差H", "",
        "釣りと同じ forecast_difference.jl を使用した合成試験。通常取引には未接続。",
        "値は試験用の主観尺度であり、価格・個数・共通の客観価値ではない。", "",
        "| 状況 | A食料確保H | A取引H | A→B交渉H | A→C交渉H | B取引H |",
        "|---|---:|---:|---:|---:|---:|"]
    function record(label)
        hs = round.([residual_h(mb) for mb in
            (a_food, a_trade, a_partner_b, a_partner_c, b_trade)]; digits=3)
        push!(report, "| $label | " * join(hs, " | ") * " |")
    end
    @testset "trade subjective forecast difference" begin
        # 返答待ち・提示だけを不成果や受領と扱わない。
        @test !observe_difference!(a_trade, 1, .8, nothing)
        @test residual_h(a_trade) == 0.
        @test isempty(a_trade.receipts)
        # 同一交換を双方が異なる見込み・観測評価で受け止める。
        @test observe_difference!(a_food, 1, 1., .3)
        @test observe_difference!(a_trade, 1, .8, .3)
        @test observe_difference!(a_partner_b, 1, .3, .3)
        @test observe_difference!(b_trade, 1, .4, .6)
        record("成立：交渉は見込みどおり、Aの上位目的には差が残る")
        @test residual_h(a_food) ≈ .7
        @test residual_h(a_trade) ≈ .5
        @test residual_h(a_partner_b) == 0.
        @test residual_h(b_trade) == 0.
        @test b_trade.observed > b_trade.expected
        @test !observe_difference!(a_trade, 1, .8, .3)
        @test residual_h(a_trade) ≈ .5
        # 逆提案は成果受領ではない。まだ結果を観測していない段階。
        @test !observe_difference!(a_trade, 2, .2, nothing)
        @test residual_h(a_trade) ≈ .5
        # 拒否も、期待の小さい交渉なら小さな差。固定の失敗1点にしない。
        @test observe_difference!(a_partner_c, 2, .1, 0.)
        @test observe_difference!(a_trade, 2, .2, 0.)
        @test observe_difference!(a_food, 2, .1, 0.)
        record("相手Cへ変更して拒否：各MBの見込みに応じた差")
        @test residual_h(a_partner_c) ≈ .1
        @test residual_h(a_trade) ≈ .7
        @test residual_h(a_food) ≈ .8
        @test residual_h(a_partner_b) == 0.
        # 同じ拒否という結果でも期待が違えばHは異なる。
        high_expectation = ForecastDifference()
        observe_difference!(high_expectation, 2, .9, 0.)
        @test residual_h(high_expectation) > residual_h(a_partner_c)
        # 次の取引で得た成果が、上位の未解消差を一部埋める。
        observe_difference!(a_partner_c, 3, .2, .4)
        observe_difference!(a_trade, 3, .2, .5)
        observe_difference!(a_food, 3, .1, .5)
        record("追加取引：交渉の差は解消、上位の差は縮小")
        @test residual_h(a_partner_c) == 0.
        @test residual_h(a_trade) ≈ .4
        @test residual_h(a_food) ≈ .4
        # 親だけの更新は子の評価を変えない。
        child_before = (residual_h(a_partner_b), residual_h(a_partner_c))
        observe_difference!(a_food, 4, 0., .5)
        @test residual_h(a_food) == 0.
        @test residual_h(a_trade) ≈ .4
        @test child_before == (residual_h(a_partner_b), residual_h(a_partner_c))
        record("別経路の成果で食料目的の差が解消：取引の評価は別に残る")
    end
    push!(report, "", "親へ子Hを転送せず、同じ出来事を各MB自身の見込み・観測で評価する。",
        "未観測の保留は無期限待機を意味しない。待ち時間の予測逸脱は別途観測・評価する必要がある。",
        "期待の生成、支払った物や関係性を含む純成果の評価、交渉終了、学習、softmax選択はこの試験の対象外。",
        "非負の目的充足尺度を入力する現行試作では、損失など負の成果を直接入力できない。通常取引への接続前に整理が必要。",
        "双方の尺度は独立。数値を個体間で比較して有利不利を断定しない。")
    write(joinpath(@__DIR__, "trade_forecast_difference_result.md"), join(report, "\n") * "\n")
end
run_trade_difference_checks()

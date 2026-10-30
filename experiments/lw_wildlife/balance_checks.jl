using Test
include("../../src/ecology/lw_grazing/balance.jl")
@testset "signed wildlife accounting residuals" begin
    a=balance_diagnostic("intake",36924.6749537778,36924.67495276554)
    @test a.status=="ok"
    @test a.residual>1e-6
    @test a.delta_since_previous===nothing
    b=balance_diagnostic("intake",36924.67495276554,36924.6749537778;previous=a)
    @test b.residual==-a.residual
    @test b.delta_since_previous==b.residual-a.residual
    c=balance_diagnostic("intake",1.,1.;previous=b)
    @test c.max_abs_residual==abs(a.residual)
    @test balance_diagnostic("zero",0.,0.).relative_error==0
    @test_logs (:warn,r"wildlife balance warning") balance_diagnostic("warn",1.,1.00001)
    @test_logs (:warn,r"wildlife balance warning") balance_diagnostic("warn",1.00001,1.)
    @test_throws ErrorException balance_diagnostic("lost bite",36924.,36924.025)
    @test_throws ErrorException balance_diagnostic("created bite",36924.025,36924.)
    for x in (NaN,Inf,-Inf)
        @test_throws ErrorException balance_diagnostic("nonfinite",x,0.)
    end
end

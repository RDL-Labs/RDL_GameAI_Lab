using Test
include(joinpath(@__DIR__,"../../src/ecology/lw_grazing/balance.jl"))
@testset "Numerical adjustment is a reporting ledger" begin
 for discrepancy in (0.,1e-7,-1e-7)
  supplied=100.;accounted=100.0 - discrepancy
  original=(supplied,accounted)
  first=balance_diagnostic("test",supplied,accounted)
  @test first.residual==supplied-accounted
  @test first.numerical_adjustment_total==first.residual
  @test first.numerical_adjustment_increment===nothing
  @test first.adjusted_residual==0.
  repeated=balance_diagnostic("test",supplied,accounted;previous=first)
  @test repeated.numerical_adjustment_increment==0.
  @test repeated.numerical_adjustment_total==first.numerical_adjustment_total
  @test (supplied,accounted)==original
 end
 first=balance_diagnostic("test",100.,100.0 - 1e-7)
 reversed=balance_diagnostic("test",100.,100.0 + 1e-7;previous=first)
 @test reversed.numerical_adjustment_increment==reversed.residual-first.residual
 @test first.numerical_adjustment_total+reversed.numerical_adjustment_increment==reversed.numerical_adjustment_total
 legacy=(residual=first.residual,max_abs_residual=abs(first.residual))
 @test balance_diagnostic("test",100.,100.;previous=legacy).numerical_adjustment_total==0.
 for args in ((100.,101.),(NaN,100.),(100.,Inf))
  @test_throws ErrorException balance_diagnostic("test",args...)
 end
 @test_throws ErrorException balance_diagnostic("test",100.,101.;previous=first)
end


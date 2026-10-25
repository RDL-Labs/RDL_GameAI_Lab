using Test
source=read(joinpath(@__DIR__,"run.jl"),String)
f=match(r"function cohort_exhausted\(daily,day_us\).*?\nend"s,source).match
include_string(Main,f)
day(reserve,rest)=Dict("physical"=>Dict(a=>Dict("body"=>Dict("reserve"=>r)) for (a,r) in zip(("a","b","c"),reserve)),"counts"=>Dict(a=>Dict("rest"=>n) for (a,n) in zip(("a","b","c"),rest)))
@test !cohort_exhausted([day([0,0,1],[10,10,10])],10_000_000)
@test !cohort_exhausted([day([0,0,0],[10,10,9])],10_000_000)
@test cohort_exhausted([day([0,0,0],[10,10,10])],10_000_000)
@test !cohort_exhausted([day([0,0,0],[10,10,10]),day([0,0,0],[10,10,10])],10_000_000)
@test cohort_exhausted([day([0,0,0],[10,10,9]),day([0,0,0],[20,20,19])],10_000_000)
println("cohort stopping checks: 5 PASS")

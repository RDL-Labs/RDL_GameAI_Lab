# Same benchmark, reverse measured order to expose first-run compilation effects.
fit_reverse_path=joinpath(@__DIR__,"benchmark_recognition_reuse.jl")
fit_reverse_source=read(fit_reverse_path,String)
fit_reverse_anchor="((\"before\",false),(\"after\",true))"
count(fit_reverse_anchor,fit_reverse_source)==1 || error("order anchor")
fit_reverse_source=replace(fit_reverse_source,fit_reverse_anchor=>"((\"after\",true),(\"before\",false))")
Base.include_string(Main,fit_reverse_source,fit_reverse_path)
cp(@__FILE__,joinpath(FIT_BENCH_OUT,basename(@__FILE__)))

# Isolate an existing integration-test failure from the candidate optimization.
test_path=abspath(joinpath(@__DIR__,"../rock_gate/parent_plan_switch_checks.jl"))
source=read(test_path,String)
anchor="include(\"../../integrations/lightweight_julia/native.jl\")"
@assert count(anchor,source)==1
reference=read(joinpath(ARGS[1],"source/src/lw/learning/mb_parent.jl"),String)
reference="function mb_parent_candidates!"*first(split(last(split(reference,"function mb_parent_candidates!")),"function mb_parent_begin!"))
replacement="include("*repr(abspath(joinpath(@__DIR__,"../../integrations/lightweight_julia/native.jl")))*");Base.include_string(Main,"*repr(reference)*")"
Base.include_string(Main,replace(source,anchor=>replacement),test_path)

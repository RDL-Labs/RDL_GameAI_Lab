using Test, Random, Serialization, JSON3
const queue_root=abspath(ARGS[1])
include(joinpath(queue_root,"source/src/lw/LW.jl"))
include("queue_merge_overlay.jl")
mktempdir() do directory
    queue_merge_overlay(joinpath(queue_root,"source/src/lw/learning"),directory)
    Base.include(LW,joinpath(directory,"mb_map.jl"))
    Base.include(LW,joinpath(directory,"mb_return_outlook.jl"))
end
reference=read(joinpath(queue_root,"source/src/lw/learning/mb_return_outlook.jl"),String)
reference=replace(first(split(reference,"function mb_return_estimate")),"function mb_return_outlook!("=>"function mb_return_outlook_reference!(")
Base.include_string(LW,reference)
reference=read(joinpath(queue_root,"source/src/lw/learning/mb_map.jl"),String)
reference="function mb_search"*first(split(last(split(reference,"function mb_search")),"function mb_outgoing"))
Base.include_string(LW,replace(reference,"function mb_search("=>"function mb_search_reference("))
include("queue_merge_fixture_checks.jl")
rows=Any[]
@testset "saved graphs retain paths, expansion counts and return state" begin
    for day in (38,40)
        saved=deserialize(joinpath(queue_root,"run/checkpoints/day-"*lpad(day,3,'0')*".jls")).state
        for actor in sort(collect(keys(saved[:mb_maps])))
            memory=saved[:mb_maps][actor];now=day*17_280_000_000
            for goal in ("food","home")
                key=memory["current"].key
                @test LW.mb_search(memory,key,goal,now)==LW.mb_search_reference(memory,key,goal,now)
            end
            results=Dict{String,Any}();times=Dict{String,Any}()
            for iteration in 0:3
                order=iseven(iteration) ? ("baseline","merged") : ("merged","baseline")
                for mode in order
                    work=deepcopy(memory);haskey(work,"return_outlook") && (work["return_outlook"]["next_us"]=0)
                    f=mode=="baseline" ? LW.mb_return_outlook_reference! : LW.mb_return_outlook!
                    measurement=@timed f(work,now)
                    results[mode]=measurement.value
                    iteration>0 && push!(get!(()->Any[],times,mode),(seconds=measurement.time,bytes=measurement.bytes))
                end
                @test results["baseline"]==results["merged"]
            end
            push!(rows,(day,actor,times))
        end
    end
end
write(ARGS[2],JSON3.write((scope="1800 queue fixtures; actual graph search and 8 return rebuilds, alternating local timing repeats after warmup",rows)))

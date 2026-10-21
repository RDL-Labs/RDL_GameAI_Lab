using Test, JSON3
root=normpath(joinpath(@__DIR__,".."))
baseline=joinpath(root,"outputs/refactor-variants-baseline")
overgrazing_days=isempty(ARGS) ? 10 : parse(Int,only(ARGS))
isdir(baseline) || error("Frozen pre-refactor sources are required")
function load_prefix(path,marker)
    m=Module(gensym(:Variant))
    Core.eval(m, :(include(p)=Base.include(@__MODULE__,joinpath($(dirname(path)),p))))
    text=read(path,String); pos=findfirst(marker,text)
    pos===nothing && error("Missing prefix boundary")
    Base.include_string(m,text[1:prevind(text,first(pos))],path)
    m
end
@testset "predator and vision variant parity" begin
    old=Module(:OldPredator);new=Module(:NewPredator)
    Base.include(old,joinpath(baseline,"predator-cpu/Predators.jl"))
    Base.include(new,joinpath(root,"src/ecology/predator-cpu/Predators.jl"))
    spec=JSON3.read(read(joinpath(baseline,"predator-cpu/map-spec.json"),String))
    for seed in 20261005:20261007, predator in (false,true)
        @test old.Predators.simulate(spec;seed,predator)==new.Predators.simulate(spec;seed,predator)
    end
    for variant in ("motion-vision-cpu","directional-vision-cpu")
        old=load_prefix(joinpath(baseline,variant,"experiment.jl"),"spec=JSON3.read")
        new=Module(gensym(:Current))
        Core.eval(new, :(include(p)=Base.include(@__MODULE__,p)))
        Base.include(new,joinpath(root,"src/ecology",variant,"trial.jl"))
        spec=JSON3.read(read(joinpath(baseline,variant,"map-spec.json"),String))
        for seed in 20261005:20261009, enabled in (false,true)
            kwargs=variant=="motion-vision-cpu" ? (;seed,motion=enabled) : (;seed,motion=true,directional=enabled)
            @test Base.invokelatest(()->old.trial(spec;kwargs...))==Base.invokelatest(()->new.trial(spec;kwargs...))
        end
    end
end
@testset "overgrazing parity" begin
    old=load_prefix(joinpath(baseline,"overgrazing-cpu/run.jl"),"simulate(1;days=0)")
    new=load_prefix(joinpath(root,"experiments/numeric_ecology/overgrazing-cpu/run.jl"),"simulate(1;days=0)")
    for n in (30,1000,3000)
        @test Base.invokelatest(()->old.simulate(n;days=overgrazing_days))==Base.invokelatest(()->new.simulate(n;days=overgrazing_days))
    end
end

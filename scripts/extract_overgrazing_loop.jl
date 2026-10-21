root=normpath(joinpath(@__DIR__,".."))
path=joinpath(root,"experiments/numeric_ecology/overgrazing-cpu/run.jl")
text=replace(read(path,String),"\r\n"=>"\n")
a=findfirst("function simulate(n;days=10)",text)
b=findfirst("simulate(1;days=0)",text)
a===nothing && error("Already migrated")
body=text[first(a):prevind(text,first(b))]
body=replace(body,"function simulate(n;days=10)\n    w,a=H.build(scenario(n);seed=SEED); alive=trues(n)"=>
    "function simulate_overgrazing(spec;days=10,seed=20261005,progress=nothing)\n    n=length(spec.scene.positions)\n    w,a=H.build(spec;seed); alive=trues(n)")
body=replace(body,"println(JSON3.write((initial=n,day=r.day,alive=r.alive,grass_pct=100r.grass_fraction)))\n                flush(stdout)"=>
    "progress===nothing || progress((initial=n,day=r.day,alive=r.alive,grass_pct=100r.grass_fraction))")
body=replace(body,"days=days,seed=SEED"=>"days=days,seed=seed")
write(joinpath(root,"src/ecology/overgrazing-cpu/simulation.jl"),body)
wrapper="include(joinpath(@__DIR__, \"../../../src/ecology/overgrazing-cpu/simulation.jl\"))\nfunction simulate(n;days=10)\n    simulate_overgrazing(scenario(n);days,seed=SEED,progress=r->println(JSON3.write(r)))\nend\n"
write(path,replace(text,text[first(a):prevind(text,first(b))]=>wrapper))

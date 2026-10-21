root=normpath(joinpath(@__DIR__,".."))
variants=("predator-cpu","motion-vision-cpu","directional-vision-cpu","overgrazing-cpu")
normalize(s)=replace(s,"\r\n"=>"\n")
for variant in variants
    old=joinpath(root,"experiments/numeric_ecology",variant)
    dest=joinpath(root,"src/ecology",variant)
    isdir(dest) && error("Already migrated: $variant")
    # Freeze the pre-refactor sources and input for independent parity runs.
    baseline=joinpath(root,"outputs/refactor-variants-baseline",variant)
    mkpath(baseline);mkpath(dest)
    for file in readdir(old)
        (endswith(file,".jl") || file=="map-spec.json") && cp(joinpath(old,file),joinpath(baseline,file);force=false)
    end
    geometry=read(joinpath(old,"Geometry.jl"),String)
    normalize(geometry)==normalize(read(joinpath(root,"src/geometry/RDLMigrationProbe.jl"),String)) || error("Geometry mismatch")
    for file in ("Herbivores.jl","Predators.jl")
        isfile(joinpath(old,file)) || continue
        text=read(joinpath(old,file),String)
        text=replace(text,"include(\"Geometry.jl\")"=>"include(\"../../geometry/RDLMigrationProbe.jl\")")
        write(joinpath(dest,file),text)
        write(joinpath(old,file),"# Compatibility entry.\ninclude(joinpath(@__DIR__, \"../../../src/ecology/$variant/$file\"))\n")
    end
    if variant in ("motion-vision-cpu","directional-vision-cpu")
        path=joinpath(old,"experiment.jl")
        text=normalize(read(path,String))
        splitpoint=first(findfirst("spec=JSON3.read",text))
        core=text[1:prevind(text,splitpoint)]
        core=replace(core,"using JSON3, Random, Test"=>"using JSON3, Random")
        write(joinpath(dest,"trial.jl"),core)
        write(path,"using JSON3, Random, Test\ninclude(joinpath(@__DIR__, \"../../../src/ecology/$variant/trial.jl\"))\n"*text[splitpoint:end])
    end
end
# This variant's animal rules are byte-identical: share one implementation.
a=joinpath(root,"src/ecology/predator-cpu/Herbivores.jl")
b=joinpath(root,"src/ecology/overgrazing-cpu/Herbivores.jl")
normalize(read(a,String))==normalize(read(b,String)) || error("Overgrazing rules differ")
write(b,"include(\"../predator-cpu/Herbivores.jl\")\n")
a=joinpath(root,"src/ecology/motion-vision-cpu/Herbivores.jl")
b=joinpath(root,"src/ecology/directional-vision-cpu/Herbivores.jl")
normalize(read(a,String))==normalize(read(b,String)) || error("Directional herbivore rules differ")
write(b,"include(\"../motion-vision-cpu/Herbivores.jl\")\n")
println("Migrated ecology variants; frozen baselines saved in outputs")

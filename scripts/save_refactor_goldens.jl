using JSON3, SHA
include("../test/canonical_json.jl")
root=normpath(joinpath(@__DIR__,".."))
path=joinpath(root,"test/fixtures/refactor-goldens.json")
isfile(path) && error("Golden already exists; do not regenerate from changed implementation")
hashes=Dict("lw/$mode"=>report_hash(joinpath(root,"outputs/refactor-baseline/$mode-result.json")) for mode in ("off","ordinary","meat"))
base=joinpath(root,"outputs/refactor-herbivore-baseline")
hashes["herbivore/result"]=report_hash(joinpath(base,"result.json"))
for name in ("trajectory.csv","grass.csv")
    hashes["herbivore/$name"]=bytes2hex(sha256(read(joinpath(base,name))))
end
mkpath(dirname(path))
write(path,JSON3.write((source_commit="a37eb00",julia="1.13.1",platform="Windows",hashes=hashes)))

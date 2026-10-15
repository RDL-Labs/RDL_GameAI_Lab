using Test, JSON3, SHA
include("../src/RDLMigrationProbe.jl")
using .RDLMigrationProbe
root = normpath(joinpath(@__DIR__, "../../fixtures"))
meta = JSON3.read(read(joinpath(root,"hashes.json"),String))
rows = [JSON3.read(s) for s in eachline(joinpath(root,"geometry_inputs.jsonl"))]
expected = [JSON3.read(s).value for s in eachline(joinpath(root,"geometry_expected.jsonl"))]
queries = prepare.(rows)
snapshot = copy(queries)
actual = batch(queries)
differences = Any[]
for i in eachindex(actual)
    a,b = actual[i],expected[i]
    ok = b === nothing ? a === nothing : b isa Bool ? (a isa Bool && a==b) :
         a isa Float64 && abs(a-b)<=1e-12+1e-12*abs(b)
    ok || push!(differences, Dict("id"=>i-1,"expected"=>b,"actual"=>a))
end
out = get(ENV,"JULIA_PROBE_OUTPUT","outputs/julia_migration/correctness")
mkpath(out)
write(joinpath(out,"correctness.json"),JSON3.write(Dict("cases"=>length(actual),"differences"=>differences)))
!isempty(differences) && write(joinpath(out,"first_difference.json"),JSON3.write(first(differences)))
@testset "frozen geometry" begin
    @test isempty(differences)
    @test actual == batch(queries)
    @test queries == snapshot
    actual[1] = 123.0
    @test batch(queries)[1] != 123.0
    for g in eachline(joinpath(root,"groups.jsonl"))
        g = JSON3.read(g)
        @test nearest(batch(queries[Int.(g.indices).+1])) == g.nearest
    end
    for (file,digest) in pairs(meta.hashes)
        @test bytes2hex(sha256(read(joinpath(root,String(file))))) == digest
    end
end
@testset "wrapper domain (not original Python contract)" begin
    base = (kind="ray", start=[0.,0.], vector=[1.,0.], circle=[1.,0.,1.], margin=0.)
    for bad in ((start=[0.],), (vector=[0.,0.],), (circle=[1.,0.,-1.],),
                (margin=-1.,), (start=[NaN,0.],), (start=[Inf,0.],),
                (start=[10001.,0.],), (kind="unknown",), (start=[true, false],))
        @test_throws ArgumentError prepare(merge(base,bad))
    end
end

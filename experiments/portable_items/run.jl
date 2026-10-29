# Frozen-source placement run. Interaction choices are deliberately not forced.
using JSON3, Test, SHA
length(ARGS)==2 || error("usage: run.jl INPUT.json NEW_OUTPUT")
const original=abspath(ARGS[1]);const out=abspath(ARGS[2])
const repo=normpath(joinpath(@__DIR__,"../.."))
ispath(out) && error("fresh output required")
const input=JSON3.read(read(original,String))
isempty(get(input.scene,:configured_item_actions,Any[])) || error("placement run requires no scripted item actions")
const placed=get(input.scene,:loose_items,get(input.scene,:portable_items,Any[]))
isempty(placed) && error("place loose items first")
println("PLACEMENT ONLY: $(input.config.days) days; $(length(placed)) non-food objects; no collecting reward/policy; no scripted item actions")
mkpath(out);const snapshot=joinpath(out,"source");mkpath(joinpath(snapshot,"integrations"))
cp(joinpath(repo,"src"),joinpath(snapshot,"src"))
cp(joinpath(repo,"integrations/lightweight_julia"),joinpath(snapshot,"integrations/lightweight_julia"))
cp(@__FILE__,joinpath(out,"runner.jl"));cp(original,joinpath(out,"input.json"))
write(joinpath(out,"origin.json"),JSON3.write((path=original,sha256=bytes2hex(sha256(read(original))))))
include(joinpath(snapshot,"integrations/lightweight_julia/native.jl"))
native_main([joinpath(out,"run"),"--spec",joinpath(out,"input.json"),"--checkpoint-dir",joinpath(out,"checkpoints")])
r=JSON3.read(read(joinpath(out,"run/result.json"),String))
@testset "placed objects remain finite, without a collection policy" begin
    @test length(r.daily)==input.config.days
    @test r.portable_items.remaining_counts==r.portable_items.initial_counts
    @test length(unique(i.id for i in r.portable_items.items))==length(placed)
    @test all(iszero,values(r.portable_items.counts))
    @test all(i.owner===nothing for i in r.portable_items.items)
    for d in r.daily
        @test d.portable_items.remaining_counts==r.portable_items.initial_counts
        @test r.initial_food+d.replenished_food==d.ground+d.shared_stock+d.consumed+sum(a.inventory+a.personal_stock for a in values(d.physical))
    end
end
write(joinpath(out,"completed.json"),JSON3.write((kind="placement-only",days=input.config.days,
    remaining=r.portable_items.remaining_counts,counts=r.portable_items.counts)))
println("COMPLETED placement-only run; autonomous item behavior is not implemented")

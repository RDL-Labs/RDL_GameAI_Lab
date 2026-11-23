using Test
include("../../src/body/RDLBody.jl")
using .RDLBody
const M=RDLBody.Macronutrients
@testset "queued nutrition changes eating evaluation only" begin
 p=M.MacroParameters()
 b=M.MacroBody(sugar=15.,fat=180.,amino=0.)
 before=deepcopy(b)
 @test M.body_signals(b,p)==M.body_signals(b,p;pending_nutrition=true)
 M.feed!(b,(15.,6.,20.),p)
 actual=M.body_snapshot(b,p)
 pending=M.body_signals(b,p;pending_nutrition=true)
 @test pending.body_demand==0
 @test pending.sugar_demand==pending.protein_demand==pending.fat_demand==0
 @test M.body_signals(b,p).sugar_demand>0
 @test M.body_snapshot(b,p)==actual
 @test b.sugar==before.sugar && b.fat==before.fat && b.tissue==before.tissue
 # Transfer from gut to absorbed pools cannot count the same nutrient twice.
 b.sugar+=5.;b.amino+=2.;b.fat+=4.;b.gut=(10.,4.,16.)
 after=M.body_signals(b,p;pending_nutrition=true)
 @test (after.sugar_need,after.protein_need,after.fat_need)==(pending.sugar_need,pending.protein_need,pending.fat_need)
 fish=M.MacroBody(sugar=0.,fat=180.,amino=0.,gut=(0.,20.,0.))
 @test M.body_signals(fish,p;pending_nutrition=true).sugar_need==1
 injured=M.MacroBody(tissue=90.,amino=0.,gut=(0.,6.,0.))
 @test M.body_signals(injured,p;pending_nutrition=true).protein_need≈0.2
end

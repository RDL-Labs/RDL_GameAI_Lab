using JSON3, Test
const out=abspath(ARGS[1])
const result=JSON3.read(read(joinpath(out,"run/result.json"),String))
const input=JSON3.read(read(joinpath(out,"input.json"),String))
const voice=JSON3.read(read(joinpath(out,"want_voice_result.json"),String))
const event_counts=Dict{String,Int}()
for record in voice.records
    event=String(record.event);event_counts[event]=get(event_counts,event,0)+1
end
const calls=[r for r in voice.records if r.event=="call"]
const bodies=Dict{String,Any}()
@testset "macro communication audit" begin
    @test length(result.daily)==input.config.days
    @test input.scene.open_stores===false
    for (index,actor) in enumerate(input.scene.experimental_actor_ids)
        dig=result.digestion[Symbol(actor)];body=dig.macronutrients
        @test abs(dig.energy_residual)<1e-6
        @test body.energy+body.spent+body.conversion_loss+body.excreted-body.ingested≈232input.scene.reserve[index]/100+108
        @test body.ingested≈20dig.eaten
        bodies[actor]=(meals=dig.eaten,sugar=body.sugar,fat=body.fat,tissue=body.tissue,
            demand=body.body_demand,unmet=body.unmet,residual=dig.energy_residual)
    end
    @test all(haskey(r.gradient,:nutrient_demand) for r in calls)
end
const report=(days=length(result.daily),trade_counts=result.portable_items.counts,event_counts,
    calls=[(actor=r.actor,us=r.us,kind=r.requested_food,nutrient_demand=r.gradient.nutrient_demand,total=r.gradient.total) for r in calls],
    replies=[r for r in voice.records if r.event=="reply"],bodies)
write(joinpath(out,"macro_trade_summary.json"),JSON3.write(report))
println(JSON3.write(report))

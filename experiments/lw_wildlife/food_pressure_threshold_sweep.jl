# Same frozen day-014; only actor16's gate thresholds differ. No production tuning.
include("food_pressure_rabbit16.jl")
thresholds=length(ARGS)>2 ? parse.(Float64,split(ARGS[3],',')) : [1.,2.,4.,8.,12.,16.,18.,20.,21.,24.,32.]
rows=Any[]
baseline=trial(false)
for enter_H in thresholds
    settings=merge(RABBIT_FOOD_PRESSURE_GATE,(enter_H=enter_H,exit_H=enter_H/2))
    result=trial(true;thresholded=true,gate_settings=settings)
    @test filter(p->p.tick<243748,baseline.samples)==filter(p->p.tick<243748,result.samples)
    activated=findfirst(r->r.active,result.gate.records)
    activation_tick=activated===nothing ? nothing : result.gate.records[activated].tick
    if activation_tick!==nothing
        @test [(p.tick,p.position,p.energy) for p in baseline.samples if p.tick<activation_tick]==
              [(p.tick,p.position,p.energy) for p in result.samples if p.tick<activation_tick]
    end
    feeding=findfirst(p->p.tick>243838 && p.state=="graze",result.samples)
    row=(enter_H,exit_H=settings.exit_H,alive=result.alive,energy=result.energy,eaten=result.eaten,
         peakH=result.peakH,blocked=result.blocked,gate=result.gate,activation_tick,
         feeding=feeding===nothing ? nothing : result.samples[feeding],seconds=result.seconds)
    push!(rows,row)
    write(output,JSON3.write((conditions=RABBIT_FOOD_PRESSURE,thresholds,rows,complete=false)))
    println(JSON3.write(row));flush(stdout)
end
write(output,JSON3.write((conditions=RABBIT_FOOD_PRESSURE,thresholds,rows,complete=true)))

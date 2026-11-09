include("food_pressure_rabbit16.jl")
old=trial(true;thresholded=true)
cooled=trial(true;thresholded=true,intake_cooling=true)
@test old.alive==cooled.alive
@test old.energy==cooled.energy
@test old.eaten==cooled.eaten
@test [(p.tick,p.position) for p in old.samples]==[(p.tick,p.position) for p in cooled.samples]
summary(r)=(alive=r.alive,energy=r.energy,eaten=r.eaten,gate=r.gate,peakH=r.peakH)
write(output,JSON3.write((old=summary(old),cooled=summary(cooled))))
println(JSON3.write((old=summary(old),cooled=summary(cooled))))

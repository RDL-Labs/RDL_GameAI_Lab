# 暫定固定の採食量ベンチ: 一区画に同居、探索選択時はその場で待機。
# 通常個体には接続しない。繁殖・捕食者なし、休息/睡眠/消化は通常身体モデル。
using JSON3,Test
include("../../src/ecology/motion-vision-cpu/Herbivores.jl")
const H=Herbivores
include("../../src/lw/configured_paths/rabbit_held_patch.jl")
struct HeldPatch end
H.choose_state(::HeldPatch,o)=configured_rabbit_held_patch(H.choose_state(H.StateMachinePolicy(),o),H.SEARCH,H.REST)
function trial(n;days=30,regrowth_days=.1,renewal=true,capacity=9.)
 input=JSON3.read(read("outputs/lw-rabbit-family-30d-20261106/input.json",String))
 base=merge((;pairs(input.scene)...),(positions=Tuple{Float64,Float64}[],))
 w,_=H.build((scene=base,);seed=20261028)
 k=findfirst(k->w.capacity[k]>0 && H.clear(w,H.center(w,k),H.center(w,k)),eachindex(w.capacity))
 position=H.center(w,k)
 w,a=H.build((scene=merge(base,(positions=fill(position,n),)),);seed=20261028)
 w.capacity[k]=capacity;w.grass[k]=capacity;w.initial=sum(w.grass)
 H.enable_grass_layers!(w;regrowth_days,renewal)
 demand=zeros(length(w.grass));ratio=similar(demand);requests=zeros(n);active=Int[]
 rows=Any[];before=0.;short_min=w.layers.short[k];depleted_ticks=0;steady_min=Inf
 for t in 0:days*17280-1
  H.step!(w,a,t,demand,ratio,requests,active;policy=HeldPatch())
  short_min=min(short_min,w.layers.short[k])
  if t>=17280
   steady_min=min(steady_min,w.layers.short[k])
   depleted_ticks+=w.layers.short[k]<.005
  end
  if (t+1)%17280==0
   H.grass!(w,k,t+1)
   @assert isapprox(w.initial+w.grown,sum(w.grass)+w.eaten;atol=1e-5,rtol=1e-9)
   @assert isapprox(w.eaten,sum(a.consumed);atol=1e-5,rtol=1e-9)
   @assert all(==(position[1]),a.x) && all(==(position[2]),a.z)
   push!(rows,(day=div(t+1,17280),short=w.layers.short[k],long=w.layers.long[k],short_fraction=w.layers.short[k]/(capacity*.6),daily_eaten=w.eaten-before,energy=copy(a.energy),zero_energy=count(==(0.),a.energy)))
   before=w.eaten
  end
 end
 (n,capacity,renewal,regrowth_days,short_min,steady_min,depleted_fraction=depleted_ticks/((days-1)*17280),short_eaten=w.layers.short_eaten,long_eaten=w.layers.long_eaten,rows)
end
results=Any[]
for c in [(n=1,rate=2.,renewal=false,cap=9.),(n=1,rate=.1,renewal=true,cap=10000.),
 (n=1,rate=.2,renewal=true,cap=9.),(n=1,rate=.15,renewal=true,cap=9.),(n=1,rate=.1,renewal=true,cap=9.),
 (n=2,rate=.1,renewal=true,cap=9.),(n=4,rate=.1,renewal=true,cap=9.),
 (n=1,rate=.05,renewal=true,cap=9.),(n=2,rate=.05,renewal=true,cap=9.),(n=4,rate=.05,renewal=true,cap=9.)]
 r=trial(c.n;regrowth_days=c.rate,renewal=c.renewal,capacity=c.cap);push!(results,r)
 println(JSON3.write((n=r.n,capacity=r.capacity,rate=r.regrowth_days,renewal=r.renewal,last=r.rows[end],short_min=r.short_min)));flush(stdout)
end
write(ARGS[1],JSON3.write((completed=true,days=30,results)))

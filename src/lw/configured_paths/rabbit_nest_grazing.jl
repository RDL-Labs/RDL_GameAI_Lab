# 暫定固定：advance!(...;nest_grazing_avoidance=true)（既定ON）。
# 自分の生存・離乳前の子の位置を直接参照し、同じセルでの採食評価に反発を加える。
# 移動/授乳/逃走は禁じない。他個体には作用しない。草の観測量・実量を変更しない。
# 将来は子・巣の認識と遮蔽維持の関係MBから得る行動別勾配に置換する。
const RABBIT_NEST_GRAZING=(capacity_multiplier=4.,cost_floor=1.)
function configured_rabbit_nest_grazing(s,t;enabled=true)
    (!enabled || s.life===nothing) && return nothing
    protected=Dict{Int,Set{Int}}()
    for i in eachindex(s.alive)
        s.alive[i] && dependent(s.life,i,t) || continue
        mother=s.life.mother[i]
        mother>0 && s.alive[mother] || continue
        push!(get!(()->Set{Int}(),protected,mother),H.cell(s.world,s.animals.x[i],s.animals.z[i]))
    end
    isempty(protected) && return nothing
    (actor,cell)->haskey(protected,actor) && cell in protected[actor] ?
        RABBIT_NEST_GRAZING.cost_floor+RABBIT_NEST_GRAZING.capacity_multiplier*s.world.capacity[cell] : 0.
end

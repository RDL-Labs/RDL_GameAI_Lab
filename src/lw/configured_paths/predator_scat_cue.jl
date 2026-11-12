# 暫定固定: 兎の糞を獲物の手がかりと知る。scat_state指定時のみON。
# 種別ラベルの識別は初期知識の近道。将来は見た目/匂いと経験MBの照合へ置換。
# 体臭と加算せず最大の手がかりを選ぶ。獲物の現在位置や生死は参照しない。
const PREDATOR_SCAT_CUE=(signal_scale=4.,old_weight=.25,amount_cap=1.)
function configured_predator_scat_cue(traces,scent,p,i,t,best)
    body=p.visual.body;selected=nothing
    for cue in configured_scat_observe(traces,body.x,body.z,t;radius=PREY_SCENT.radius)
        cue.kind==0x01 || continue
        target=(cue.x,cue.z);key=prey_scent_cell(target...)
        scent.cautious && t<get(scent.cooldown[i],key,0) && continue
        distance=hypot(target[1]-body.x,target[2]-body.z)
        PREY_SCENT.arrival_radius<distance<=PREY_SCENT.radius || continue
        weight=PREDATOR_SCAT_CUE.old_weight+(1-PREDATOR_SCAT_CUE.old_weight)*cue.freshness
        signal=PREDATOR_SCAT_CUE.signal_scale*min(cue.amount,PREDATOR_SCAT_CUE.amount_cap)*weight/(1+distance)
        if signal>best
            best=signal
            selected=(target=target,signal=signal,tick=t,source=:scat,detail=cue.detail)
        end
    end
    selected
end

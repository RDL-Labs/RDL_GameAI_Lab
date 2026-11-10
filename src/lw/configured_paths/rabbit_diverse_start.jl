# 暫定固定：明示指定した新規実験の初期状態だけを分散。通常はOFF。
# 真の家族・妊娠を直接設定し行動を誘導する処理ではない。将来は準備期間で置換。
# 数値は比較用の暫定集団構成。履歴を捏造せず収支は0、胃内容は既存の0を維持。
const RABBIT_DIVERSE_START=(seed=20261109,total_count=100,original_young=5,dependent_count=15,subadult_count=20,
    family_size=5,young_age_bands=((3,9),(11,17),(19,25)),adult_age=(180,540),
    subadult_age=(35,149),reserve_range=(55.,85.),sleepy_range=(0.,1.),recovering_mothers=5)
function configured_rabbit_diverse_start!(s)
    s.ticks==0 && length(s.alive)>=RABBIT_DIVERSE_START.total_count || error("diverse start requires fresh population of at least 100 rabbits")
    rabbit_total=length(s.alive)
    life=s.life;a=s.animals;r=RABBIT_DIVERSE_START;rng=Random.Xoshiro(r.seed);day=G.RABBIT_LIFE.day_ticks
    initial_children=findall(>(0),life.mother)
    length(initial_children)==r.original_young || error("requires original five young")
    original_mother=only(unique(life.mother[initial_children]))
    eligible=shuffle(rng,[i for i in 1:(rabbit_total-r.original_young) if life.due[i]==0 && i!=original_mother])
    extra_young=r.dependent_count-r.original_young
    children=vcat(initial_children,eligible[1:extra_young]);subadults=eligible[extra_young+1:extra_young+r.subadult_count]
    adults=setdiff(collect(1:rabbit_total),vcat(children,subadults))
    mothers=vcat(original_mother,shuffle(rng,[i for i in adults if life.sex[i]==1 && life.due[i]==0 && i!=original_mother])[1:2])
    for i in adults
        life.born[i]=-rand(rng,r.adult_age[1]:r.adult_age[2])*day
    end
    for i in subadults
        life.born[i]=-rand(rng,r.subadult_age[1]:r.subadult_age[2])*day
    end
    for (family,mother) in enumerate(mothers)
        band=r.young_age_bands[family];age=rand(rng,band[1]:band[2])
        for i in children[(family-1)*r.family_size+1:family*r.family_size]
            life.born[i]=-age*day;life.mother[i]=mother;life.nursed_day[i]=0
            life.moving[i]=false;a.state[i]=H.SLEEP;a.energy[i]=G.RABBIT_LIFE.milk_target
        end
        life.next_mate[mother]=(G.RABBIT_LIFE.wean_days+G.RABBIT_LIFE.recovery_days-age)*day
    end
    recovering=shuffle(rng,[i for i in adults if life.sex[i]==1 && life.due[i]==0 && !(i in mothers)])[1:r.recovering_mothers]
    for i in recovering
        life.next_mate[i]=rand(rng,1:G.RABBIT_LIFE.recovery_days)*day
    end
    # Keep initial conception count/litter sizes but disperse gestation ages; reset ledger together.
    for i in findall(>(0),life.due)
        elapsed=rand(rng,1:G.RABBIT_LIFE.gestation_days-1)
        life.due[i]=(G.RABBIT_LIFE.gestation_days-elapsed)*day
        life.invested[i]=elapsed*G.RABBIT_LIFE.pregnancy_energy_per_day
    end
    life.gestation_out=sum(life.invested)
    # Symmetric stratification preserves mean reserve 70 for independent animals.
    independent=vcat(adults,subadults);levels=shuffle(rng,collect(range(r.reserve_range...,length=length(independent))))
    for (slot,i) in enumerate(independent)
        a.energy[i]=levels[slot];a.sleepy[i]=r.sleepy_range[1]+rand(rng)*(r.sleepy_range[2]-r.sleepy_range[1])
    end
    life.reserve_previous.=a.energy;life.reserve_balance.=0.;life.reserve_sample_tick.=0
    s
end

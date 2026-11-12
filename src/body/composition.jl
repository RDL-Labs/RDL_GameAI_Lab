# Species-independent, energy-equivalent compartments (not grams or calories).
# Protein minimum is structural tissue, excluded from usable energy.
mutable struct Composition
    available::Float64
    fat::Float64
    protein::Float64
    protein_min::Float64
    protein_target::Float64
    collapse_protein::Float64
    collapsed::Bool
    fed_since_collapse::Bool
    alive::Bool
end
function Composition(;available,fat,protein,protein_min,protein_target,collapse_protein)
    all(isfinite,(available,fat,protein,protein_min,protein_target,collapse_protein)) || throw(ArgumentError("finite composition"))
    available>=0 && fat>=0 && 0<=protein_min<collapse_protein<protein_target && protein_min<=protein<=protein_target || throw(ArgumentError("composition bounds"))
    Composition(available,fat,protein,protein_min,protein_target,collapse_protein,protein<=collapse_protein,false,protein>protein_min)
end
composition_energy(c)=c.available+c.fat+max(0.,c.protein-c.protein_min)
composition_mobility(c)=!c.alive || c.collapsed ? 0. : clamp((c.protein-c.protein_min)/(c.protein_target-c.protein_min),0.,1.)
function composition_consume!(c,amount)
    isfinite(amount) && amount>=0 || throw(ArgumentError("consumption"))
    c.alive || return 0.
    used=min(amount,composition_energy(c));remaining=used
    take=min(c.available,remaining);c.available-=take;remaining-=take
    take=min(c.fat,remaining);c.fat-=take;remaining-=take
    c.protein=max(c.protein_min,c.protein-remaining)
    if !c.collapsed && c.protein<=c.collapse_protein
        c.collapsed=true;c.fed_since_collapse=false
    end
    c.protein<=c.protein_min && (c.alive=false)
    used
end
function composition_feed!(c,amount)
    isfinite(amount) && amount>=0 || throw(ArgumentError("feeding"))
    c.alive || return 0.
    c.available+=amount
    c.collapsed && amount>0 && (c.fed_since_collapse=true)
    amount
end
function composition_repair!(c,amount)
    isfinite(amount) && amount>=0 || throw(ArgumentError("repair"))
    c.alive || return 0.
    c.collapsed && !c.fed_since_collapse && return 0.
    transfer=min(amount,c.available,c.protein_target-c.protein)
    c.available-=transfer;c.protein+=transfer
    # Full tissue restoration before standing; no free recovery from resting.
    if c.collapsed && c.fed_since_collapse && c.protein>=c.protein_target
        c.collapsed=false;c.fed_since_collapse=false
    end
    transfer
end
composition_snapshot(c)=(available=c.available,fat=c.fat,protein=c.protein,usable=composition_energy(c),mobility=composition_mobility(c),collapsed=c.collapsed,alive=c.alive)

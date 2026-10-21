function choose_state(old,energy,gut,sleepy,grass,threat)
    threat && return FLEE
    old==SLEEP && sleepy>.15 && energy>25 && return SLEEP
    sleepy>=1 && energy>30 && return SLEEP
    (energy>=85 || gut>=3.8 || (old==REST && energy>65 && gut>1.5)) && return REST
    grass>=.005 && gut<4 && return GRAZE
    SEARCH
end
struct StateMachinePolicy end

choose_state(::StateMachinePolicy, o) = choose_state(o.old,o.energy,o.gut,o.sleepy,o.grass,o.threat)

function choose_target(::StateMachinePolicy, observations, heading, previous_cell)
    best=0; score=-Inf
    for o in observations
        o===nothing && continue
        value=o.grass-.25o.distance+.2cos(o.direction-heading)-(o.cell==previous_cell ? 1. : 0.)
        if value>score; score=value; best=o.cell; end
    end
    best
end

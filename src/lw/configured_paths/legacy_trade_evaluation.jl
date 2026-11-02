# Compatibility only: pre-relational experiments. Do not use as the default
# evaluation contract for relation-enabled LW runs.
legacy_unobserved_food_count(fallback)=fallback

function legacy_food_trade_resolve!(loop,source,expected,actual,exchanged,tolerance)
    pressure=max(0.,expected-actual-tolerance,-actual-tolerance)
    useful=exchanged && actual>tolerance
    if useful && pressure==0.
        resolve_method!(loop,source,true,true;goal_H_increment=0.,completion_reward=actual-tolerance)
    elseif pressure>0.
        resolve_method!(loop,source,useful,false;creditable=useful,goal_H_increment=pressure)
    else
        resolve_method!(loop,source,nothing,nothing;creditable=false,goal_H_increment=0.)
    end
end

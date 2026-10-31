# World-only supply schedule; not exposed to agent observations or forecasts.
function seasonal_food_config(spec,renewable,interval)
    s=get(spec,:food_season,nothing)
    s===nothing && return nothing
    renewable && interval==1 || error("food_season requires renewable food and daily regrowth")
    p=get(s,:period_days,0);lo=get(s,:low_rate,-1);hi=get(s,:high_rate,-1);phase=get(s,:phase_days,0)
    all(x->x isa Real && !(x isa Bool) && isfinite(x),(p,lo,hi,phase)) || error("invalid food_season values")
    p>=2 && 0<=lo<=hi || error("invalid food_season range")
    (period_days=Float64(p),low_rate=Float64(lo),high_rate=Float64(hi),phase_days=Float64(phase))
end
function seasonal_food_integral(s,t)
    mean=(s.low_rate+s.high_rate)/2;amplitude=(s.high_rate-s.low_rate)/2
    mean*t+amplitude*s.period_days/(2pi)*(sinpi(2*(t+s.phase_days)/s.period_days)-sinpi(2*s.phase_days/s.period_days))
end
function seasonal_replenish_food!(stock,food,s,day;capacity=0)
    day>=1 || error("seasonal regeneration needs an elapsed day")
    added=0
    # Absolute cumulative production preserves fractional growth across days/resume.
    # Fixed per-site rounding offsets spread integer arrivals without consuming RNG.
    for (i,f) in enumerate(food)
        get(f,:renewable,true) || continue
        cap=capacity>0 ? capacity : Int(f.stock)
        offset=(i-.5)/length(food)
        previous=floor(Int,cap*seasonal_food_integral(s,day-1)+offset+1e-9)
        current=floor(Int,cap*seasonal_food_integral(s,day)+offset+1e-9)
        amount=min(max(0,cap-stock[i]),max(0,current-previous))
        stock[i]+=amount;added+=amount
    end
    added # Capacity-blocked production is discarded, never banked for later harvest.
end

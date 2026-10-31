# Initial expression-emission adapter, not a physiological model or a diagnosis.
# Several bodily causes deliberately produce the same public distress signal.
function configured_expression(body;fear=0.,anxiety=0.)
    distress=clamp(max((60-body.reserve)/60,body.strain,body.damage,clamp(anxiety,0.,1.)),0.,1.)
    afraid=clamp(Float64(fear),0.,1.)
    (calm=1-max(distress,afraid),distress=distress,fear=afraid)
end

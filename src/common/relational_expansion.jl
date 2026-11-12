# Shared bounded expansion: small early response, increasing slope, finite ceiling.
function relational_expansion_fraction(pressure;full_H=20.,curvature=3.)
    isfinite(full_H) && full_H>0 || throw(ArgumentError("full_H"))
    isfinite(curvature) && 0<=curvature<=50 || throw(ArgumentError("curvature"))
    isnan(pressure) && throw(ArgumentError("pressure"))
    h=clamp(pressure/full_H,0.,1.)
    curvature==0 ? h : expm1(curvature*h)/expm1(curvature)
end

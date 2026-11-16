# Relative intensity, not decibels or a calibrated biological model.
# Finite at zero range; reusable for speech, footsteps and other point sources.
function received_sound_strength(volume::Real,distance::Real;reference_distance::Real=4.)
    all(isfinite,(volume,distance,reference_distance)) || throw(ArgumentError("finite sound inputs required"))
    volume>=0 && distance>=0 && reference_distance>0 || throw(ArgumentError("invalid sound inputs"))
    Float64(volume)/(1+(Float64(distance)/reference_distance)^2)
end

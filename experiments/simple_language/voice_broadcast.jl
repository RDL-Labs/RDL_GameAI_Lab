include("../../src/perception/sound_level.jl")
# 暫定固定 sensory settings for a local experiment, not normal LW defaults.
# World distance units, relative intensity, degrees. Replace thresholds with
# measured/learned perception later; no forced orientation, reply or agreement.
const VOICE_BROADCAST=(reference_distance=4.,notice_strength=.04,word_strength=.15,bearing_step=15.)
function voice_observation(world,source,listener,text;volume=1.,attending=false)
    p=world.positions[listener];q=world.positions[source]
    dx,dz=q[1]-p[1],q[2]-p[2]
    strength=received_sound_strength(volume,hypot(dx,dz);reference_distance=VOICE_BROADCAST.reference_distance)
    world.hearing[listener] || return nothing
    strength>=VOICE_BROADCAST.notice_strength || return nothing
    clear=attending && strength>=VOICE_BROADCAST.word_strength
    # No true speaker ID, private intent, exact distance or offer terms exposed.
    (strength=strength,bearing=VOICE_BROADCAST.bearing_step*round(atand(dx,dz)/VOICE_BROADCAST.bearing_step),
     text=clear ? text : "",words_available=clear)
end
function broadcast_voice(world,source,text;volume=1.,attention=Dict())
    # One emission projected independently to all other individuals. Pure read.
    isfinite(volume) && volume>=0 || throw(ArgumentError("invalid volume"))
    Dict(listener=>voice_observation(world,source,listener,text;volume,attending=get(attention,listener,false))
        for listener in sort(collect(keys(world.positions))) if listener!=source)
end

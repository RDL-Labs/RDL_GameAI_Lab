# Continue only a previously chosen simple movement, never select a new goal.
# State is stored in mb_maps for checkpoint continuity. Complex MB route steps
# retain their normal transition checks and are deliberately not enrolled yet.
function gradient_roll_state(m)
 get!(m,"gradient_roll",D("active"=>false,"next_us"=>0,"interval"=>1.,"heading"=>0.,
 "family"=>"","phase"=>"","H"=>0.,"last_us"=>-1,"continued"=>0,"checks"=>0,
 "enrolled"=>0,"reasons"=>D(),"plan"=>nothing,"speed"=>.5))
end
function gradient_roll_plan!(m,receipt,now,yaw,family,phase,H,target)
 s=gradient_roll_state(m);s["active"] || return nothing
 gap=receipt===nothing || get(receipt,"after_us",-1)!=now || s["last_us"]!=now-1_000_000
 step=receipt===nothing ? 0. : hypot(receipt["forward"],receipt["right"])
 # Track the observed goal in the egocentric frame; never invent a goal
 # from a heading. Odometry changes distance even while the goal is unseen.
 turn=receipt===nothing ? 0. : Float64(receipt["yaw"])
 if !gap
  f=s["target_forward"]-receipt["forward"];r=s["target_right"]-receipt["right"]
  sn,cs=sincosd(turn)
  s["target_forward"]=f*cs+r*sn;s["target_right"]=r*cs-f*sn
  s["uncertainty"]+=.02step+.0005abs(turn)
 end
 observed=target!==nothing && haskey(target,"forward") && haskey(target,"right")
 mismatch=observed && hypot(target["forward"]-s["target_forward"],target["right"]-s["target_right"])>max(1.,s["uncertainty"]+.1hypot(s["target_forward"],s["target_right"]))
 if observed && get(s,"cue_kind","")=="sky"
  # Skyline distance is a band estimate. Reobserving the same band must not
  # reset odometric progress back to its representative distance every tick.
  old_angle=rad2deg(atan(s["target_right"],s["target_forward"]))
  new_angle=rad2deg(atan(target["right"],target["forward"]))
  mismatch=abs(mod(new_angle-old_angle+180,360)-180)>30
  d_est=hypot(s["target_forward"],s["target_right"])
  target=D("forward"=>d_est*cosd(new_angle),"right"=>d_est*sind(new_angle),"distance"=>d_est)
 end
 if observed && !mismatch
  s["target_forward"]=Float64(target["forward"]);s["target_right"]=Float64(target["right"])
  s["uncertainty"]=.25;s["observed_us"]=now
 end
 d=hypot(s["target_forward"],s["target_right"])
 s["expected"]=get(s,"expected",0.)+get(s,"reference_speed",.5)
 s["progress"]=s["check_distance"]-d
 near=d<=max(1.5,2step)
 arrived=d<=1.25
 due=now>=s["next_us"] || near
 reason=gap ? "gap" : family!=s["family"] || phase!=s["phase"] ? "purpose" :
  step<.001 ? "stopped" : H>s["H"]+1e-6 ? "residual" : mismatch ? "target_mismatch" :
  now-s["observed_us"]>8_000_000 || s["uncertainty"]>1. ? "target_uncertain" :
  arrived ? "arrival" : due && s["progress"]<max(.01,.25min(s["expected"],max(0.,s["check_distance"]-1.25))) ? "distance_shortfall" : due ? "confirmed" : "continue"
 s["reasons"][reason]=get(s["reasons"],reason,0)+1;s["last_us"]=now;s["speed"]=max(.01,step)
 if !(reason in ("continue","confirmed"))
  s["active"]=false;s["checks"]+=1;s["interval"]=1.
  s["reconsidered"]=get(s,"reconsidered",0)+1
  return nothing
 end
 if reason=="confirmed"
  s["checks"]+=1;s["confirmed"]=get(s,"confirmed",0)+1
  s["interval"]=near ? 1. : min(8.,2s["interval"])
  limit=max(1.,.25max(0.,d-1.25)/max(.01,step))
  s["next_us"]=now+round(Int,1e6min(s["interval"],limit))
  s["check_distance"]=d;s["progress"]=0.;s["expected"]=0.;s["reference_speed"]=max(.01,step)
 end
 threshold=get(s,"direction_distance",0.)
 mode=threshold>0 && d>threshold ? "direction" : "approach"
 previous=get(s,"mode",mode)
 previous!=mode && (s["mode_switches"]=get(s,"mode_switches",0)+1)
 s["mode"]=mode
 if reason=="confirmed"
  s["far_heading"]=yaw+rad2deg(atan(s["target_right"],s["target_forward"]))
 end
 s[mode*"_ticks"]=get(s,mode*"_ticks",0)+1
 p=copy(s["plan"])
 p["steering_angle"]=mode=="direction" ? mod(s["far_heading"]-yaw+180,360)-180 : rad2deg(atan(s["target_right"],s["target_forward"]))
 p["gradient_roll_mode"]=mode
 p["direction"]=argmin(abs.(ANGLES .- p["steering_angle"]))-1
 p["gradient_roll"]=true;s["continued"]+=1
 get(s,"cue_kind","")!="" && (s["cue_continued"]=get(s,"cue_continued",0)+1)
 p
end
function gradient_roll_enroll!(m,p,now,yaw,family,phase,H,target;direction_distance=0.)
 get(p,"gradient_roll",false) && return
 s=gradient_roll_state(m)
 method=get(p,"method","")
 cue=get(p,"cue_kind","") in ("shape","sky") && get(p,"cue_distance",nothing)!==nothing
 if cue
  d=Float64(p["cue_distance"]);angle=Float64(p["cue_angle"])
  target=D("distance"=>d,"forward"=>d*cosd(angle),"right"=>d*sind(angle))
 end
 eligible=target!==nothing && haskey(target,"forward") && haskey(target,"right") &&
   (cue || (get(p,"question","")=="target_nearer" && startswith(method,"step_"))) && p["action"] in ("walk","run") &&
   !get(p,"configured_observation",false) && !get(p,"safety",false) && phase in ("exploration","return")
 if !eligible
  s["active"]=false;s["interval"]=1.;return
 end
 angle=get(p,"steering_angle",Float64(ANGLES[p["direction"]+1]))
 heading=mod(yaw+angle+180,360)-180
 abs(mod(heading-s["heading"]+180,360)-180)>15 && (s["interval"]=1.)
 speed=p["action"]=="run" ? 1.5 : .5
 limit=target===nothing ? 2. : max(1.,.25max(0.,target["distance"]-1.25)/speed)
 s["next_us"]=now+round(Int,1e6min(s["interval"],limit))
 s["plan"]=D("action"=>p["action"],"method"=>method,"question"=>get(p,"question","movement_progress"),"priority"=>get(p,"priority",0.),"direction"=>p["direction"])
 s["cue_kind"]=cue ? p["cue_kind"] : "";s["cue_label"]=cue ? p["cue_label"] : ""
 if cue
  s["cue_enrolled"]=get(s,"cue_enrolled",0)+1
  labels=get!(s,"cue_labels",D());labels[s["cue_label"]]=get(labels,s["cue_label"],0)+1
 end
 s["heading"]=heading;s["family"]=family;s["phase"]=phase;s["H"]=H;s["last_us"]=now
 s["target_forward"]=Float64(target["forward"]);s["target_right"]=Float64(target["right"])
 s["check_distance"]=hypot(s["target_forward"],s["target_right"]);s["uncertainty"]=.25;s["observed_us"]=now
 s["direction_distance"]=Float64(direction_distance);s["far_heading"]=yaw+rad2deg(atan(s["target_right"],s["target_forward"]))
 s["mode"]=direction_distance>0 && s["check_distance"]>direction_distance ? "direction" : "approach"
 s["progress"]=0.;s["expected"]=0.;s["reference_speed"]=speed
 s["active"]=true;s["enrolled"]+=1
end

# Match perceptual description and predicted bearing, not world object identity.
function gradient_roll_observed_target(m,fallback,landmarks,sky)
 s=get(m,"gradient_roll",nothing)
 (s===nothing || !get(s,"active",false) || get(s,"cue_kind","")=="") && return fallback
 view=s["cue_kind"]=="sky" ? sky : landmarks
 (view===nothing || get(view,"coverage","")!="complete") && return nothing
 patches=landmark_patches(view,s["cue_label"])
 patches===nothing && return nothing
 angle=rad2deg(atan(s["target_right"],s["target_forward"]))
 candidates=filter(p->p["distance"]!==nothing && abs(mod(p["angle"]-angle+180,360)-180)<=30,patches)
 length(candidates)==1 || return nothing # ambiguous correspondence remains unknown
 p=only(candidates);d=p["distance"]
 D("distance"=>d,"forward"=>d*cosd(p["angle"]),"right"=>d*sind(p["angle"]))
end
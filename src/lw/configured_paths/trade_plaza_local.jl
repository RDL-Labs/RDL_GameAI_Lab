# 暫定固定・局所実験のみ（通常LWでは未include、既定OFF）。全員が広場を
# 知るショートカット。将来は場所との関係MBと合流計画に置換する。
# 広場中心は呼出側で指定。半径0.5は接触半径1.25内へ集合する暫定余裕。
const TRADE_PLAZA_LOCAL_RULES=(arrival_radius=0.5,)
function configured_trade_plaza_local(state,plaza,position,yaw,rows,sight,trade_partners)
    meeting=configured_camp_trade_state!(state)["meeting"]
    meeting===nothing && return nothing
    peer=meeting["peer"]
    peer in trade_partners && return nothing
    dx,dz=plaza[1]-position[1],plaza[2]-position[2]
    near=hypot(dx,dz)<=TRADE_PLAZA_LOCAL_RULES.arrival_radius
    seen=findfirst(p->p["ref"]==peer,sight["peers"])
    stage="plaza"
    if near && seen!==nothing
        angle=sight["peers"][seen]["angle"]
        forward,right=cosd(angle),sind(angle)
        stage="peer"
    elseif near
        return D("action"=>"scan","method"=>"trade_plaza_search","configured_rule"=>"trade_plaza_local")
    else
        sn,cs=sincosd(yaw);forward,right=dx*sn+dz*cs,dx*cs-dz*sn
    end
    viable=filter(r->r["cost"]!==nothing && r["clear"],rows)
    isempty(viable) && return D("action"=>"scan","method"=>"trade_plaza_blocked","configured_rule"=>"trade_plaza_local")
    row=viable[argmin([hypot(forward-cosd(ANGLES[parse(Int,r["ref"])+1]),right-sind(ANGLES[parse(Int,r["ref"])+1])) for r in viable])]
    D("action"=>"walk","direction"=>parse(Int,row["ref"]),"method"=>"trade_plaza_"*stage,"configured_rule"=>"trade_plaza_local")
end

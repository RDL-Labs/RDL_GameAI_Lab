# 暫定固定: 世界の矩形境界を直接参照する内向き勾配。学習・感覚ではない。
# wildlife.boundary_gradient (既定false)。動物実験は明示ON。
# 将来は観測された地形/行動範囲の関係勾配へ置換する。
const WILDLIFE_BOUNDARY=(width=8.0,strength=2.0,body_margin=.25)
function configured_boundary_heading(w,p,heading)
    w.boundary_gradient || return heading
    rule=WILDLIFE_BOUNDARY
    pressure(d)=clamp(1-d/rule.width,0.,1.)^2
    gx=rule.strength*(pressure(p[1]-w.xmin-rule.body_margin)-pressure(w.xmax-rule.body_margin-p[1]))
    gz=rule.strength*(pressure(p[2]-w.zmin-rule.body_margin)-pressure(w.zmax-rule.body_margin-p[2]))
    gx==0 && gz==0 && return heading
    dx=cos(heading)+gx;dz=sin(heading)+gz
    hypot(dx,dz)<1e-12 && return atan(gz,gx)
    atan(dz,dx)
end
function configured_boundary_step(w,p,heading,speed)
    h=configured_boundary_heading(w,p,heading)
    (p[1]+speed*cos(h),p[2]+speed*sin(h))
end

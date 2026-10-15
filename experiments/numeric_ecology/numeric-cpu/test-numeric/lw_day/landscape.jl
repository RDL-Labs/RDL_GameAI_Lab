# World-only riparian material field; reference lightweight/base_landscape.py.
river_x(phase,z)=12+5sin((z-6)/22+phase)
river_width(z)=1.2+.4*(1+sin(z/13))
function landscape_material(land,p)
    x,z=p;d=abs(x-river_x(land.phase,z))
    d<=river_width(z)/2 && return "water"
    d<4 && return "bank"
    (((x+28)/18)^2+((z-28)/24)^2<1 || ((x-37)/17)^2+((z+20)/25)^2<1) && return "forest"
    ((x+23)/13)^2+((z+25)/15)^2<1 && return "rockland"
    "grassland"
end
function landscape_resistance(land,p)
    m=landscape_material(land,p)
    m=="water" ? 3. : m=="bank" ? 1.8 : m=="forest" ? 2. : m=="rockland" ? 2.5 : 1.5
end

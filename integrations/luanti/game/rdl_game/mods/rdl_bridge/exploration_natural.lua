-- L13T: private finite terrain and bounded sensor/body adapters. No route oracle.
local M={}
local prefix="rdl_bridge:exploration_"
local colors={grass="green",dirt="brown",stone="gray",trunk="brown",leaves="green",water="blue"}
local supports={grass=true,dirt=true,stone=true}
local cells={{"center",0,0},{"front1",1,0},{"front2",2,0},{"right1",0,1},{"right2",0,2},
    {"left1",0,-1},{"left2",0,-2},{"back1",-1,0},{"back2",-2,0}}
local function kind(node) return node and node.name:sub(#prefix+1) end
local function round(x) return math.floor(x+.5) end
local function air(node) return node and node.name=="air" end
function M.register_surface(name,color) assert(color=="brown" or color=="gray");colors[name]=color end
function M.height(x,z)
    -- One level shallow pool, below the surrounding rolling surface.
    if (x+15)^2+(z-12)^2<=25 then return -1 end
    return round(1.4*math.sin(x/12)+1.2*math.sin(z/15)+math.sin((x+z)/18))
end
function M.register()
    for name,color in pairs({grass="#6e9047",dirt="#86694c",stone="#72736b",trunk="#684a32",leaves="#3e6736",water="#477f9b"}) do
        core.register_node(prefix .. name,{description="L13T " .. name,
            tiles={"rdl_l13_gray.png^[colorize:" .. color .. ":180"},walkable=true,pointable=false})
    end
end
function M.build(scenario,sky_height)
    sky_height=sky_height or 18
    assert(sky_height==18 or sky_height==31,"finite sky bound")
    local lo,hi={x=-56,y=-6,z=-56},{x=56,y=sky_height,z=56}
    local vm=VoxelManip();local emin,emax=vm:read_from_map(lo,hi)
    local area=VoxelArea:new({MinEdge=emin,MaxEdge=emax});local data=vm:get_data()
    local ids={air=core.get_content_id("air")}
    for name in pairs(colors) do ids[name]=core.get_content_id(prefix .. name) end
    local counts={trees=0,rocks=0,water_columns=0};local hmin,hmax=99,-99
    for z=-56,56 do for x=-56,56 do
        local h=M.height(x,z);hmin=math.min(hmin,h);hmax=math.max(hmax,h)
        local pond=(x+15)^2+(z-12)^2<=25
        if pond then counts.water_columns=counts.water_columns+1 end
        local bare=(math.sin(x/6)+math.cos(z/8))>1.2
        for y=-6,sky_height do
            local name=y>h and "air" or (y<h and "dirt" or (pond and "water" or (bare and "dirt" or "grass")))
            data[area:index(x,y,z)]=ids[name]
        end
    end end
    -- Jittered vegetation: same draws for both densities, independent of Food/agent RNG.
    local vegetation_seed=719
    local function draw(n) vegetation_seed=(vegetation_seed*48271)%2147483647;return vegetation_seed%n end
    for bx=-28,28,8 do for bz=-28,28,8 do
        local x,z=bx+draw(7)-3,bz+draw(7)-3
        local pick=draw(5)
        if x*x+z*z>25 and pick<(scenario=="natural_woodland" and 4 or 1) and (x+15)^2+(z-12)^2>36 then
            local h=M.height(x,z);counts.trees=counts.trees+1
            for y=h+1,h+4 do data[area:index(x,y,z)]=ids.trunk end
            for yy=h+3,h+5 do for xx=x-2,x+2 do for zz=z-2,z+2 do
                if math.abs(xx-x)+math.abs(zz-z)+(yy==h+5 and 1 or 0)<=3 and (xx~=x or zz~=z) then
                    data[area:index(xx,yy,zz)]=ids.leaves
                end
            end end end
        end
    end end
    for _,p in ipairs({{8,7},{-9,-6},{22,-14},{-23,24}}) do
        counts.rocks=counts.rocks+1
        for x=p[1]-1,p[1]+1 do for z=p[2]-1,p[2]+1 do
            local h=M.height(x,z)
            for y=h+1,h+(x==p[1] and z==p[2] and 3 or 2) do data[area:index(x,y,z)]=ids.stone end
        end end
    end
    vm:set_data(data);vm:write_to_map();vm:update_map()
    -- Actual node readback, retained only in experimenter evidence.
    local read=VoxelManip();local rmin,rmax=read:read_from_map(lo,hi)
    local ra=VoxelArea:new({MinEdge=rmin,MaxEdge=rmax});local rd=read:get_data();local names={};local rows={}
    for z=-56,56 do for y=-6,sky_height do for x=-56,56 do
        local id=rd[ra:index(x,y,z)];names[id]=names[id] or core.get_name_from_content_id(id)
        rows[#rows+1]=names[id]
    end end end
    local columns={}
    for z=-32,32 do for x=-32,32 do
        local h=M.height(x,z);local top=h
        for y=18,h,-1 do if rd[ra:index(x,y,z)]~=ids.air then top=y;break end end
        columns[#columns+1]={h,core.get_name_from_content_id(rd[ra:index(x,h,z)]),
            top,core.get_name_from_content_id(rd[ra:index(x,top,z)])}
    end end
    return {schema="l13t-terrain-v1",layout=scenario,lower=lo,upper=hi,height_min=hmin,height_max=hmax,
        counts=counts,node_readback_sha1=core.sha1(table.concat(rows,"\n")),artificial_path=false,vegetation_seed=719,
        columns=columns,column_order="z=-32..32 outer; x=-32..32 inner; ground_y,node,top_y,node; experimenter-only"}
end

-- Nine fixed downward rays from the current eye; the first visible surface is sampled.
-- A trunk/rock hit is observed color, not an invented unseen floor behind it.
function M.sample(position,yaw,read)
    local f=core.yaw_to_dir(yaw);local r={x=f.z,y=0,z=-f.x};local eye=vector.add(position,{x=0,y=.5,z=0})
    local out={model="l13t-local-surface-rays-v1",profile="l13t-natural-fixed-v1",coverage="complete",cells={}}
    for _,c in ipairs(cells) do
        local finish=vector.add(position,{x=f.x*c[2]+r.x*c[3],y=-3,z=f.z*c[2]+r.z*c[3]})
        local delta=vector.subtract(finish,eye);local steps=math.ceil(vector.length(delta)/.125)
        local color,status="unknown","no_surface"
        for i=0,steps do
            local n=read(vector.round(vector.add(eye,vector.multiply(delta,i/steps))))
            if not n or n.name=="ignore" then status="unloaded";break end
            if not air(n) then
                color=colors[kind(n)] or "unknown";status=color=="unknown" and "occluded" or "sampled";break
            end
        end
        out.cells[#out.cells+1]={cell_id=c[1],color=color,status=status}
        if status~="sampled" then out.coverage="partial" end
    end
    return out
end

-- Quarter-node collision samples with at most one-node vertical change for this move.
-- Only local node reads; no height-map lookup, path search, jump, teleport over an obstacle or fall.
function M.destination(pos,dir,read)
    local audit={samples={}}
    local final
    for i=1,4 do
        local p=vector.add(pos,vector.multiply(dir,i/4))
        if math.abs(p.x)>32.00001 or math.abs(p.z)>32.00001 then audit.reason="boundary";return nil,audit end
        local found
        for dy=1,-1,-1 do
            local floor={x=round(p.x),y=round(pos.y)-1+dy,z=round(p.z)}
            local foot={x=floor.x,y=floor.y+1,z=floor.z};local head={x=floor.x,y=floor.y+2,z=floor.z}
            local a,b,c=read(floor),read(foot),read(head)
            audit.samples[#audit.samples+1]={floor=floor,support=a and a.name or "ignore",foot=b and b.name or "ignore",head=c and c.name or "ignore"}
            if a and supports[kind(a)] and air(b) and air(c) then found=foot.y;break end
        end
        if not found then audit.reason="unsupported_or_obstructed";return nil,audit end
        final={x=p.x,y=found,z=p.z}
    end
    audit.reason="supported_step";return final,audit
end

function M.visibility(eye,target,read)
    local delta=vector.subtract(target,eye);local n=math.max(1,math.ceil(vector.length(delta)/.125))
    for i=0,n do
        local p=vector.round(vector.add(eye,vector.multiply(delta,i/n)));local node=read(p)
        if not node or node.name=="ignore" then return false,"partial" end
        if not air(node) then return false,"complete" end
    end
    return true,"complete"
end
return M

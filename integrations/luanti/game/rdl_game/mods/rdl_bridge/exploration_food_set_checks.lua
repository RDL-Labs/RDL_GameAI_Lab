return function(M)
    local n=0
    local function check(x) assert(x);n=n+1 end
    local function object(ref,z)
        local o={position={x=0,y=1,z=z}}
        function o:get_pos() return self.position end
        function o:get_luaentity() return {rdl_id=ref} end
        function o:remove() self.position=nil end
        return o
    end
    local foods={object("far",20),object("near",1),object("other",2),object("occluded",3),object("missing",4)}
    local reads=0
    local visible,coverage,audit=M.sample(foods,{x=0,y=1,z=0},0,function(_,p)
        reads=reads+1
        return p.z<3,p.z==4 and "partial" or "complete"
    end)
    check(reads==4);check(#audit==5);check(coverage=="partial")
    check(#visible==2);check(visible[1].ref=="near" and visible[2].ref=="other")
    check(not M.pickup(foods,"far",{x=0,y=1,z=0}))
    check(not M.pickup(foods,"absent",{x=0,y=1,z=0}))
    check(M.pickup(foods,"near",{x=0,y=1,z=0}))
    check(foods[2]==nil and foods[3]:get_pos()~=nil)
    check(not M.pickup(foods,"near",{x=0,y=1,z=0}))
    visible,coverage,audit=M.sample(foods,{x=0,y=1,z=0},0,function() return false,"complete" end)
    check(#visible==0 and coverage=="complete" and #audit==4)
    return n
end

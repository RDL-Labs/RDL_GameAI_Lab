return function(M)
    local n=0;local function check(x) assert(x);n=n+1 end
    local function patch(ref,z)
        local obj={pos={x=0,y=1,z=z}}
        function obj:get_pos() return self.pos end
        function obj:get_properties() return {visual="sprite",textures={M.texture}} end
        function obj:remove() self.pos=nil end
        return {ref=ref,object=obj,position=vector.new(obj.pos),initial=2,remaining=2}
    end
    local p={patch("a",1),patch("b",3)};local pos={x=0,y=1,z=0}
    check(not M.pickup(p,"b",pos));check(not M.pickup(p,"absent",pos))
    check(M.pickup(p,"a",pos));check(p[1].remaining==1 and p[1].object:get_pos()~=nil)
    check(M.pickup(p,"a",pos));check(p[1].remaining==0 and p[1].object==nil)
    check(not M.pickup(p,"a",pos));check(p[2].remaining==2)
    local f,c,a=M.sample(p,pos,0,function() return true,"complete" end)
    check(#f==1 and f[1].ref=="b" and f[1].appearance=="brown_capped_ovoid")
    check(c=="complete" and #a==1)
    local many={};for i=1,6 do many[i]=patch("m" .. i,i) end
    f,c,a=M.sample(many,pos,0,function() return true,"complete" end)
    check(#f==5 and #a==6 and c=="partial");check(f[1].distance==1 and f[5].distance==5)
    f,c=M.sample(many,pos,0,function() return false,"partial" end)
    check(#f==0 and c=="partial")
    f,c=M.sample(many,pos,0,function() return false,"complete" end)
    check(#f==0 and c=="complete")
    return n
end

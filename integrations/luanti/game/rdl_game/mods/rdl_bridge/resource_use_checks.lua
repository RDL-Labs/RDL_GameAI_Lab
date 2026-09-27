return function(M)
    local n=0
    local function check(x) assert(x);n=n+1 end
    for _,name in ipairs({"peer","return_unit","own"}) do
        local c=M.new(100);local calls=0
        local function action()
            calls=calls+1
            check(not c:once(name,100,0,function() calls=calls+1 end))
        end
        check(not c:once(name,99,0,action));check(calls==0)
        check(c:once(name,100,0,action));check(calls==1)
        check(not c:once(name,500000,0,action));check(c.counts[name]==1)
        local d=M.new(100)
        check(not pcall(function() d:once(name,250100,0,action) end));check(calls==1)
    end
    return n
end

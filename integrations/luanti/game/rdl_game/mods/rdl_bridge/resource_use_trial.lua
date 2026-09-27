-- Consume scheduled actions before side effects; missed slots never catch up.
local M={}
function M.new(start)
    return {start=start,done={},counts={},once=function(self,name,now,offset,action)
        assert(name=="peer" or name=="return_unit" or name=="own","unknown action")
        if self.done[name] then return false,"consumed" end
        if now<self.start+offset then return false,"early" end
        if now>=self.start+offset+250000 then error("missed action slot: " .. name) end
        self.done[name]=true;self.counts[name]=(self.counts[name] or 0)+1
        action();return true
    end}
end
return M

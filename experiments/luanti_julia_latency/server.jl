using Sockets, JSON3
include("../../src/ecology/state_ids.jl")
include("../../src/ecology/herbivore/decision.jl")

# Deliberately finite localhost benchmark protocol, not a production HTTP adapter.
function decide(body)
    o=JSON3.read(body)
    state=choose_state(Int(o.old),Float64(o.energy),Float64(o.gut),
        Float64(o.sleepy),Float64(o.grass),Bool(o.threat))
    JSON3.write((id=Int(o.id),seq=Int(o.seq),state=Int(state)))
end
decide("{\"id\":1,\"seq\":1,\"old\":1,\"energy\":70,\"gut\":0,\"sleepy\":0,\"grass\":1,\"threat\":false}")
listener=listen(ip"127.0.0.1",18765)
println("READY"); flush(stdout)
while true
    sock=accept(listener)
    try
        request=readline(sock)
        length=0
        while true
            line=strip(readline(sock))
            isempty(line) && break
            startswith(lowercase(line),"content-length:") && (length=parse(Int,strip(split(line,':';limit=2)[2])))
        end
        0<length<=4096 || error("invalid body length")
        body=String(read(sock,length))
        start=time_ns()
        payload=decide(body)
        processing_us=(time_ns()-start)/1000
        reply=JSON3.write((decision=JSON3.read(payload),processing_us=processing_us))
        write(sock,"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: $(sizeof(reply))\r\nConnection: close\r\n\r\n",reply)
        flush(sock)
    catch e
        showerror(stderr,e); println(stderr)
    finally
        close(sock)
    end
end

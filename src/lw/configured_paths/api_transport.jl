# Transport policy only: simulated time/RNG/choices do not advance while waiting.
# Retry only explicit temporary rate limits, never quota/authentication failures.
const CONFIGURED_API_RETRY_LIMIT=8
function configured_api_retry_delay(status,raw,headers,attempt)
    status==429 || return nothing
    error_data=try JSON3.read(raw) catch;return nothing end
    get(get(error_data,:error,Dict()),:code,nothing)=="rate_limit_exceeded" || return nothing
    for (key,value) in headers
        if lowercase(key)=="retry-after"
            delay=tryparse(Float64,value)
            delay!==nothing && isfinite(delay) && delay>=0 && return delay+1
        end
    end
    hint=match(r"try again in ([0-9.]+)(ms|s|m)"i,String(get(error_data.error,:message,"")))
    hint===nothing && return min(60.,2.0^attempt)
    parse(Float64,hint[1])*(hint[2]=="ms" ? .001 : hint[2]=="m" ? 60. : 1.)+1
end
function configured_api_http(payload)
    buffer=IOBuffer()
    response=Downloads.request("https://api.openai.com/v1/responses";method="POST",
        headers=["Authorization"=>"Bearer "*ENV["OPENAI_API_KEY"],"Content-Type"=>"application/json"],
        input=IOBuffer(JSON3.write(payload)),output=buffer,timeout=120)
    (status=response.status,headers=response.headers,body=String(take!(buffer)))
end
const CONFIGURED_API_SEND_OVERRIDE=Ref{Any}(nothing)
function configured_api_request(payload,label;send=p->CONFIGURED_API_SEND_OVERRIDE[]===nothing ? configured_api_http(p) : CONFIGURED_API_SEND_OVERRIDE[](p,label),pause=sleep)
    for attempt in 1:CONFIGURED_API_RETRY_LIMIT
        response=send(payload)
        response.status==200 && return response.body
        write(joinpath(OUTPUT,"$label-error-$attempt.json"),response.body)
        delay=configured_api_retry_delay(response.status,response.body,response.headers,attempt)
        (delay===nothing || attempt==CONFIGURED_API_RETRY_LIMIT) && error("API HTTP $(response.status); retry unavailable/exhausted ($label)")
        open(joinpath(OUTPUT,"api-retries.jsonl"),"a") do io
            println(io,JSON3.write((request=label,attempt=attempt,wait_seconds=delay,status=response.status)))
        end
        while delay>0
            interval=min(60.,delay);pause(interval);delay-=interval
        end
    end
    error("unreachable")
end

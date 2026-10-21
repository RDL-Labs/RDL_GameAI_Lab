# Stable key order for complete-report regression hashes, independent of Dict order.
canonical_json(x::AbstractDict)="{"*join((JSON3.write(k)*":"*canonical_json(x[k]) for k in sort!(collect(keys(x)))),",")*"}"
canonical_json(x::AbstractVector)="["*join(canonical_json.(x),",")*"]"
canonical_json(x)=JSON3.write(x)
report_hash(path)=bytes2hex(sha256(canonical_json(JSON3.read(read(path,String),Dict{String,Any}))))

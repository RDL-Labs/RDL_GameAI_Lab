using JSON3, Serialization
const out=abspath(ARGS[1])
if isfile(joinpath(out,"run/result.json"))
    daily=JSON3.read(read(joinpath(out,"run/result.json"),String),Dict{String,Any})["daily"]
else
    include(joinpath(out,"source/integrations/lightweight_julia/native.jl"))
    files=sort(filter(f->endswith(f,".jls"),readdir(joinpath(out,"checkpoints");join=true)))
    daily=deserialize(files[end]).state[:daily]
end
const rows=Any[]
for (day,snapshot) in enumerate(daily), actor in sort(collect(keys(snapshot["digestion"])))
    dig=snapshot["digestion"][actor]; body=dig["macronutrients"]
    getfieldvalue(key)=body isa NamedTuple ? getproperty(body,Symbol(key)) : body[key]
    push!(rows,(day,actor,eaten=dig["eaten"],sugar=getfieldvalue("sugar"),fat=getfieldvalue("fat"),
        tissue=getfieldvalue("tissue"),amino=getfieldvalue("amino"),gut=getfieldvalue("gut"),
        demand=getfieldvalue("body_demand"),unmet=getfieldvalue("unmet"),
        spent=getfieldvalue("spent"),repaired=getfieldvalue("repaired"),
        energy=snapshot["physical"][actor]["body"]["energy"],alive=getfieldvalue("alive"),
        residual=dig["energy_residual"],meal_kinds=[r isa NamedTuple ? r.kind : r["kind"] for r in dig["records"]]))
end
write(joinpath(out,"nutrition_summary.json"),JSON3.write(rows))
for row in rows
    println("day=$(row.day) $(row.actor) meals=$(row.eaten) sugar=$(round(row.sugar;digits=2)) fat=$(round(row.fat;digits=2)) tissue=$(round(row.tissue;digits=2)) demand=$(round(row.demand;digits=3)) energy=$(round(row.energy;digits=2)) alive=$(row.alive) unpaid=$(row.unmet) kinds=$(row.meal_kinds)")
end

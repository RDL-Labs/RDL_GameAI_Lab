root=normpath(joinpath(@__DIR__,".."))
for relative in ("src/ecology/herbivore/ids.jl","src/ecology/predator-cpu/Herbivores.jl","src/ecology/motion-vision-cpu/Herbivores.jl")
    path=joinpath(root,relative);text=replace(read(path,String),"\r\n"=>"\n")
    pattern=r"const SEARCH=UInt8\(1\);[^\n]+\nconst WATER=UInt8\(1\);[^\n]+\n(?:const ALERT=UInt8\(6\)\n)?"
    occursin(pattern,text) || error("Missing inline IDs: $relative")
    write(path,replace(text,pattern=>"include(\"../state_ids.jl\")\n"))
end

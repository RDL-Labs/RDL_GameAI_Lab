using Test
root=normpath(joinpath(@__DIR__,".."))
source=joinpath(root,"src")
@testset "core dependency direction" begin
    count=0
    for (dir,_,files) in walkdir(source), file in files
        endswith(file,".jl") || continue
        path=joinpath(dir,file); text=read(path,String)
        @test !occursin(r"include[^\n]*experiments",text)
        @test !occursin(r"\b(?:PyCall|PythonCall)\b",text)
        for m in eachmatch(r"include\((?:joinpath\(@__DIR__,\s*)?\"([^\"]+)\"\)?\)",text)
            target=normpath(joinpath(dir,m.captures[1]))
            @test isfile(target)
            @test !startswith(relpath(target,source),"..")
            count+=1
        end
    end
    @test count>50
end

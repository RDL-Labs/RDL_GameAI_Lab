# Static inventory only: never executes the inspected experiments.
using SHA

root = normpath(joinpath(@__DIR__, ".."))
output = isempty(ARGS) ? joinpath(root, "outputs", "julia-dependencies.tsv") : abspath(ARGS[1])
mkpath(dirname(output))
files = String[]
for subtree in ("src", "integrations", "experiments", "test")
    base = joinpath(root, subtree)
    isdir(base) || continue
    for (dir, _, names) in walkdir(base), name in names
        endswith(name, ".jl") && push!(files, joinpath(dir, name))
    end
end
push!(files, joinpath(root, "run.jl"))
sort!(files)
open(output, "w") do io
    println(io, "file\tline\tcategory\tkind\tvalue")
    for file in files
        relative = replace(relpath(file, root), '\\'=>'/')
        frozen = occursin(r"numeric_ecology/numeric-cpu", relative)
        category = frozen ? "snapshot" : startswith(relative, "src/") ? "core" : "review"
        source = read(file, String)
        println(io, join((relative, 0, category, "sha256", bytes2hex(sha256(source))), '\t'))
        for (line, text) in enumerate(split(source, '\n'))
            # Preserve expressions, including dynamic includes, rather than guessing targets.
            if occursin(r"\binclude\s*\(", text)
                println(io, join((relative, line, category, "include", replace(strip(text), '\t'=>' ')), '\t'))
            end
            m = match(r"^\s*(?:mutable\s+)?struct\s+(\w+)", text)
            if m !== nothing
                println(io, join((relative, line, category, "type", m.captures[1]), '\t'))
            end
        end
    end
end
println("Inventoried $(length(files)) Julia files: $output")

using Documenter, Configurations

makedocs(;
    modules = [Configurations],
    format = Documenter.HTML(prettyurls = !("local" in ARGS)),
    pages = [
        "Home" => "index.md",
    ],
    repo = "https://github.com/Roger-luo/Configurations.jl",
    sitename = "Configurations.jl",
)

deploydocs(; repo = "github.com/Roger-luo/Configurations.jl")
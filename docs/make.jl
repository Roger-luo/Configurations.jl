using Documenter, Configurations

makedocs(;
    modules = [Configurations],
    format = Documenter.HTML(prettyurls = !("local" in ARGS)),
    pages = [
        "Home" => "index.md",
        "Quick Start" => "quick-start.md",
        "Advanced Usage" => "advance.md",
        "References" => "ref.md",
    ],
    repo = "https://github.com/Roger-luo/Configurations.jl",
    sitename = "Configurations.jl",
)

deploydocs(; repo = "github.com/Roger-luo/Configurations.jl")

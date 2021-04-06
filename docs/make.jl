using Documenter, Configurations

Themes.compile(joinpath(@__DIR__, "src/assets/main.scss"))

makedocs(;
    modules = [Configurations],
    format = Documenter.HTML(
        prettyurls = !("local" in ARGS),
        canonical="https://Roger-luo.github.io/Configurations.jl",
        assets=String["assets/main.css"],
    ),
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

# Options

[![tests](https://github.com/Roger-luo/Options.jl/workflows/tests/badge.svg)](https://github.com/Roger-luo/Options.jl/actions)

Options & Configurations made easy.

## Installation

<p>
Options is a &nbsp;
    <a href="https://julialang.org">
        <img src="https://raw.githubusercontent.com/JuliaLang/julia-logo-graphics/master/images/julia.ico" width="16em">
        Julia Language
    </a>
    &nbsp; package. To install Options,
    please <a href="https://docs.julialang.org/en/v1/manual/getting-started/">open
    Julia's interactive session (known as REPL)</a> and press <kbd>]</kbd> key in the REPL to use the package mode, then type the following command
</p>

```julia
pkg> add Options
```

## Usage

This package provides a macro `@option` to let you define `struct`s as options, and serialize between
different option/configuration file format, such as `TOML`, e.g

You can easily create hierarchical struct types as following

```julia-repl
julia> @option struct OptionA
           name::String
           int::Int = 1
       end

julia> @option struct OptionB
           opt::OptionA = OptionA(;name = "Sam")
           float::Float64 = 0.3
       end

julia> d = Dict(
           "opt" => Dict(
               "name" => "Roger",
               "int" => 2,
           ),
           "float" => 0.33
       )
Dict{String, Any} with 2 entries:
  "opt"   => Dict{String, Any}("int"=>2, "name"=>"Roger")
  "float" => 0.33

julia> option = OptionB(d)
OptionB(;
  opt = OptionA(;
    name = "Roger",
    int = 2,
  ),
  float = 0.33,
)
```

for option types you can always convert `AbstractDict` to a given option type,
or convert them back to dictionary via `Options.to_dict`, e.g

```julia
julia> Options.to_dict(option)
OrderedDict{String, Any} with 2 entries:
  "opt"   => OrderedDict{String, Any}("name"=>"Roger", "int"=>2)
  "float" => 0.33
```

for serialization, you can use the builtin TOML support

```julia
julia> Options.to_toml(option)
"float = 0.33\n\n[opt]\nname = \"Roger\"\nint = 2\n"
```

Or serialize it to other format from `OrderedDict`.

## License

MIT License

# Configurations

[![CI](https://github.com/Roger-luo/Configurations.jl/workflows/CI/badge.svg)](https://github.com/Roger-luo/Configurations.jl/actions)
[![codecov](https://codecov.io/gh/Roger-luo/Configurations.jl/branch/master/graph/badge.svg?token=U604BQGRV1)](https://codecov.io/gh/Roger-luo/Configurations.jl)

Configurations & Options made easy.

## Installation

```@raw html
<p>
Configurations is a &nbsp;
    <a href="https://julialang.org">
        <img src="https://raw.githubusercontent.com/JuliaLang/julia-logo-graphics/master/images/julia.ico" width="16em">
        Julia Language
    </a>
    &nbsp; package. To install Configurations,
    please <a href="https://docs.julialang.org/en/v1/manual/getting-started/">open
    Julia's interactive session (known as REPL)</a> and press <kbd>]</kbd> key in the REPL to use the package mode, then type the following command
</p>
```

```julia
pkg> add Configurations
```

## Usage

This package provides a macro `@option` to let you define `struct`s to represent options/configurations, and serialize between different option/configuration file format.

```@docs
@option
```

## License

MIT License

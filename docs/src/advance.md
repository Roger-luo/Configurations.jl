```@meta
CurrentModule = Configurations
```

# Advanced Usage

For most use cases, the default API [`@option`](@ref) is sufficient, however, there are some
specific cases requires one to use `Configurations`'s advanced API.

## Reflect Type

One can use `Reflect` type to denote a field contains the type information of the struct.

```@docs
Reflect
```

## Alias

### Option Type Alias

When there are multiple possible choices for an option-typed field, e.g

```julia
@option struct Options
    options::Union{OptionA, OptionB}
end
```

where `OptionA` and `OptionB` are also option types, one can specific which
option type is it by using an alias when defining `OptionA` and `OptionB`

```julia
@option "A" struct OptionA
    name::String
end

@option "B" struct OptionB
    age::Int
end
```

then you can create an `Options` from the following Julia `Dict`

```julia
Dict{String, Any}(
    "options" => Dict{String, Any}(
        "A" => Dict{String, Any}(
            "name"=>"Roger",
        )
    )
)
```

or by using the following TOML file,

```toml
[options.A]
name="Roger"
```

## Custom Option Macro

In some cases, you may not want all the features we defined by default in `Configurations`,
such as the printing, etc.

In this case, you can construct your own macro using the code generation passes defined in
`Configurations`. The code generation passes API starts with `codegen_`.

`Configurations` uses an intermediate representation defined by [Expronicon](https://github.com/Roger-luo/Expronicon.jl) to represent user defined option types,
which is the `JLKwStruct` struct.

### Builtin Code Generator

```@docs
codegen_create
codegen_is_option
codegen_convert
codegen_field_default
codegen_type_alias
codegen_isequal
```

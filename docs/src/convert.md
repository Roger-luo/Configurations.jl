# [Type Conversion and Custom Parsing](@id type-conversion)

If you find [`from_dict`](@ref) or [`from_toml`](@ref) doesn't not support a Julia type, such as `Symbol`,
this is usually because the corresponding parser or format doesn't support this Julia type natively, in this
case you will need to define your own type conversion for this option type by
overloading [`Configurations.convert_to_option`](@ref)

## How does it work?

The type conversion for option types work as following:

1. if we find the target type does not match the value type, we will call [`Configurations.convert_to_option`](@ref)
2. if [`Configurations.convert_to_option`](@ref) is not overloaded, it will return [`Configurations.ConvertNotFound`](@ref) otherwise, it will return the converted value.
3. if we see [`Configurations.ConvertNotFound`](@ref) we will call `Base.convert`, if this doesn't work, a standard conversion failure error will be thrown by `Base.convert`.

Thus, if `Base.convert` is already overloaded, this will just work, or if the conversion rule is contextual based
on the option type, one can also overload [`Configurations.convert_to_option`](@ref), this also avoids potential
type piracy.

## Example: Contextual Conversion

```julia
using Configurations

@option struct MyOption
    a::Int
    b::Symbol
end
```

directly calling `from_dict` will have the following error

```julia
julia> @option struct MyOption
           a::Int
           b::Symbol
       end

julia> d = Dict{String, Any}(
           "a" => 1,
           "b" => "ccc"
       )
Dict{String, Any} with 2 entries:
  "b" => "ccc"
  "a" => 1

julia> from_dict(MyOption, d)
ERROR: MethodError: Cannot `convert` an object of type String to an object of type Symbol
Closest candidates are:
  convert(::Type{T}, ::T) where T at essentials.jl:205
  Symbol(::String) at boot.jl:478
  Symbol(::AbstractString) at strings/basic.jl:228
  ...
```

now if we define the following type conversion

```julia
Configurations.convert_to_option(::Type{MyOption}, ::Type{Symbol}, s) = Symbol(s)
```

it will just work

```julia
julia> from_dict(MyOption, d)
MyOption(1, :ccc)
```

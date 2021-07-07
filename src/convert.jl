"""
    ConvertNotFound

Conversion is not defined via [`convert_to_option`](@ref). One should let the conversion fallback
to `Base.convert` when see this.
"""
struct ConvertNotFound end

"""
    convert_to_option(::Type{OptionType}, ::Type{ValueType}, x) where {OptionType, ValueType}

Convert `x` to type `ValueType` for option type `OptionType`. This is similar to `Base.convert`,
but will not error if the conversion is not overloaded, and will return a [`ConvertNotFound`](@ref)
object, but one can use this to avoid type piracy and define contextual conversion based on option
types.

# Example

One may have different string syntax for a `Symbol`, e.g

```julia
@option struct StringIsSymbol
    name::Symbol
end

@option struct SymbolNeedsColon
    name::Symbol
end

Configurations.convert_to_option(::Type{StringIsSymbol}, ::Type{Symbol}, x::String) = Symbol(x)

function Configurations.convert_to_option(::Type{SymbolNeedsColon}, ::Type{Symbol}, x::String)
    if startswith(x, ':')
        Symbol(x[2:end])
    else
        error("expect a Symbol, got String")
    end
end
```

then if we run it, we will have different behaviour by context.

```julia
julia> from_dict(StringIsSymbol, d)
StringIsSymbol(:ccc)

julia> from_dict(SymbolNeedsColon, d)
ERROR: expect a Symbol, got String
```
"""
convert_to_option(::Type, ::Type{T}, x) where T = convert_to_option(T, x)
convert_to_option(::Type{T}, x) where T = ConvertNotFound()

# built-in type conversion support
convert_to_option(::Type{VersionNumber}, x) = VersionNumber(x)

function convert_union_to_option(::Type{T}, ::Type{A}, x) where {T, A}
    if A isa Union
        value = convert_to_option(T, A.a, x)

        if value isa ConvertNotFound
            value = convert_to_option(T, A.b, x)
        end
    else
        value = convert_to_option(T, A, x)
    end

    value isa ConvertNotFound && return convert(A, x)
    return value
end

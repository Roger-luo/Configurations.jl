"""
    convert_to_option(::Type{OptionType}, ::Type{ValueType}, x) where {OptionType, ValueType}

Convert `x` to type `ValueType` for option type `OptionType`. This is similar to `Base.convert`,
when creating an instance of the option type, but one can use this to avoid type piracy.
"""
convert_to_option(::Type, ::Type{A}, x) where {A} = nothing

convert_to_option(::Type, ::Type{VersionNumber}, x::String) = VersionNumber(x)

function convert_union_to_option(::Type{T}, ::Type{A}, x) where {T, A}
    if !(A isa Union)
        v = convert_to_option(T, A, x)
        v === nothing || return v
        return
    end

    v = convert_union_to_option(T, A.a, x)
    v === nothing || return v
    return convert_union_to_option(T, A.b, x)
end

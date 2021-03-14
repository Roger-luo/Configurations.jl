"""
    option_convert(::Type{OptionType}, ::Type{ValueType}, x) where {OptionType, ValueType}

Convert `x` to type `ValueType` for option type `OptionType`. This is similar to `Base.convert`,
when creating an instance of the option type, but one can use this to avoid type piracy.
"""
option_convert(::Type, ::Type{A}, x) where {A} = nothing

option_convert(::Type, ::Type{VersionNumber}, x::String) = VersionNumber(x)

function option_convert_union(::Type{T}, ::Type{A}, x) where {T, A}
    if !(A isa Union)
        v = option_convert(T, A, x)
        v === nothing || return v
        return
    end

    v = option_convert_union(T, A.a, x)
    v === nothing || return v
    return option_convert_union(T, A.b, x)
end

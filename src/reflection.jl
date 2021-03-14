"""
    field_default(::Type{T}, name::Symbol)

Return the default value of field `name` of an option type `T`.
"""
function field_default(::Type{T}, name::Symbol) where {T}
    error("field_default is not defined for $T, it may not be an option type")
end

"""
    field_defaults(::Type)

Return default values of given option types.
"""
function field_defaults(::Type{T}) where T
    is_option(T) || error("$T is not an option type")
    return Any[field_default(T, each) for each in fieldnames(T)]
end

"""
    field_alias(::Type{T}) where T

Return all field name alias of given option types.
"""
function field_aliases(::Type{T}) where T
    is_option(T) || error("$T is not an option type")
    return Any[field_alias(T, each) for each in fieldnames(T)]
end

"""
    field_alias(::Type{T}, name::Symbol) where {T}

Return field name alias of given option types.
"""
function field_alias(::Type{T}, name::Symbol) where {T}
    error("field_alias is not defined for $T, it may not be an option type")
end

"""
    type_alias(::Type{OptionType}) -> String

Return the alias name of given `OptionType`.
"""
function type_alias(::Type{T}) where T
    error("type alias is not defined $T, it may not be an option type")
end

@deprecate alias(T) type_alias(T)

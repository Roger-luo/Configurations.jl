"""
    ignore_extra(option_type) -> Bool

Return `true` if the option type ignores extra fields when
read from a dict-like object.

!!! note
    Normally, we require the dict-like object to have exactly the same
    number of fields with the option type. However, it could be useful
    to have ignore extra fields when wrapping network work services to
    ignore some irrelavent optional fields.

!!! note
    Unlike [pydantic](https://pydantic-docs.helpmanual.io/usage/model_config/),
    we do not allow dynamically adding fields to a given type. One should manually
    define fields you would like to include in a struct type and let it to have
    type `Dict{String, Any}`.

# Example

```julia
julia> Configurations.ignore_extra(::Type{MyOption}) = true
```
"""
function ignore_extra(::Type{OptionType}) where {OptionType}
    is_option(OptionType) || error("expect an option type")
    return false
end

"""
    field_alias(::Type{OptionType}, field::OptionField) where {OptionField}

Return `String` if there is an alias for the `field` of `OptionType`, otherwise
return `nothing`. This is an overloadable interface to define an alias of the field.
"""
function field_alias(::Type{OptionType}, ::OptionField) where {OptionField}
    is_option(OptionType) && return
    throw(ArgumentError("$OptionType is not an option type"))
end

"""
    to_dict(option; include_defaults=false) -> OrderedDict

Convert an option to an `OrderedDict`. 

!!! tips
    `to_dict` does not export fields that are of the same values as the defaults. 
    In most cases, this should be the default behaviour, and users should not use
    `include_defaults`, however,  this can be overridden by changing `include_defaults`
    to `true`.
"""
function to_dict(x; include_defaults=false)
    is_option(x) || error("argument is not an option type")
    return dictionalize(x, include_defaults)::OrderedDict
end

"""
    dictionalize(x, include_defaults=false)

Convert `x` to an `OrderedDict`. This is only for internal usage
or for other implementation to re-use the generic method for converting
a Julia struct to `OrderedDict`,for overloading one should overload
[`to_dict`](@ref) for custom conversion.
"""
function dictionalize(x, include_defaults=false)
    is_option(x) || return x
    d = OrderedDict{String, Any}()
    T = typeof(x)
    for name in fieldnames(T)
        type = fieldtype(T, name)
        value = getfield(x, name)
        if include_defaults || value != field_default(T, name)
            field_dict = dictionalize(value, include_defaults)

            # always add an alias if it's a Union
            # of multiple option types
            if is_option(value) && type isa Union
                d[string(name)] = OrderedDict{String, Any}(
                    type_alias(typeof(value)) => field_dict,
                )
            else
                d[string(name)] = field_dict
            end
        end
    end
    return d
end

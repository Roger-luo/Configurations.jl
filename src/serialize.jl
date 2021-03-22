"""
    to_dict(option; include_defaults=false) -> OrderedDict

Convert an object to an `OrderedDict`. 

!!! tips
    `to_dict` does not export fields that are of the same values as the defaults. 
    In most cases, this should be the default behaviour, and users should not use
    `include_defaults`, however,  this can be overridden by changing `include_defaults`
    to `true`.
"""
to_dict(x; include_defaults::Bool=false) = to_dict(x, include_defaults)
to_dict(x::Union{String, Int, Float64}) = x # TOML compatible types
to_dict(x::VersionNumber) = string(x)

function to_dict(x, include_defaults)
    if !is_option(x)
        x isa OrderedDict || error("method to_dict is not overloaded for non-option type $(typeof(x))")
        return x
    end

    d = OrderedDict{String, Any}()
    T = typeof(x)
    for name in fieldnames(T)
        type = fieldtype(T, name)
        value = getfield(x, name)
        if include_defaults || value != field_default(T, name)
            if is_option(value)
                field_dict = to_dict(value, include_defaults)
            else
                field_dict = to_dict(value)
            end

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

"""
    to_toml([f::Function], io::IO, option; sorted=false, by=identity, include_defaults=false)

Convert an instance `option` of option type to TOML and write it to `IO`. See also `TOML.print`.
"""
function to_toml(f, io::IO, x; sorted::Bool=false, by=identity, include_defaults::Bool=false)
    is_option(x) || error("argument is not an option type")
    d = to_dict(x; include_defaults=include_defaults)
    return TOML.print(f, io, d; sorted=sorted, by=by)
end

"""
    to_toml([f::Function], filename::String, option; sorted=false, by=identity, include_defaults=false)

Convert an instance `option` of option type to TOML and write it to `filename`. See also `TOML.print`.
"""
function to_toml(f, filename::String, x; sorted::Bool=false, by=identity, include_defaults::Bool=false)
    open(filename, "w+") do io
        to_toml(f, io, x; sorted=sorted, by=by, include_defaults=include_defaults)
    end
end

function to_toml(io::IO, x; sorted::Bool=false, by=identity, include_defaults::Bool=false)
    return to_toml(identity, io, x; sorted=sorted, by=by, include_defaults=include_defaults)
end

function to_toml(filename::String, x; sorted::Bool=false, by=identity, include_defaults::Bool=false)
    return to_toml(identity, filename, x; sorted=sorted, by=by, include_defaults=include_defaults)
end

"""
    to_toml(x; sorted=false, by=identity, include_defaults=false)

Convert an instance `x` of option type to TOML and write it to `String`. See also `TOML.print`. 

`to_toml` does not export fields that are of the same values as the defaults. This can be 
overridden by changing `include_defaults` to `true`.
"""
function to_toml(x; sorted::Bool=false, by=identity, include_defaults::Bool=false)
    return sprint(x) do io, x
        to_toml(io, x; sorted=sorted, by=by, include_defaults=include_defaults)
    end
end

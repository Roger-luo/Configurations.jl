function assert_option(x)
    is_option(x) || error("$(typeof(x)) is not an option type")
end

"""
    to_dict(option; include_defaults=false) -> OrderedDict

Convert an object to an `OrderedDict`. 

!!! tips
    `to_dict` does not export fields that are of the same values as the defaults. 
    In most cases, this should be the default behaviour, and users should not use
    `include_defaults`, however,  this can be overridden by changing `include_defaults`
    to `true`.
"""
function to_dict(x; include_defaults::Bool=false)
    assert_option(x)
    return to_dict(typeof(x), x, include_defaults)
end

"""
    to_dict(::Type{T}, x, include_defaults::Bool) where T

Convert `x` when `x` is inside an option type `T`. `include_defaults`
is a flag to determine whether to include the default values. this can
be overloaded to change the behaviour of `to_dict(x; include_defaults)`.

    to_dict(::Type{T}, x) where T

One can also use the 2-arg version when `x` is not or does not
contain an option type for convenience.

# Example

The following is a builtin overload to handle list of options.

```julia
function Configurations.to_dict(::Type{T}, x::Vector, include_defaults::Bool) where T
    if is_option(eltype(x))
        return map(p->to_dict(T, p, include_defaults), x)
    else
        return x
    end
end
```

The following overloads the 2-arg `to_dict` to convert all `VersionNumber` to
a `String` for all kinds of option types.

```julia
Configurations.to_dict(::Type, x::VersionNumber) = string(x)
```
"""
function to_dict(::Type{T}, x, include_defaults::Bool) where T
    if is_option(x)
        return _option_to_dict(x, include_defaults)
    else
        return to_dict(T, x) # fall through 2-arg version
    end
end

to_dict(::Type, x) = x

# handle list of options as builtin
function to_dict(::Type{T}, x::Vector, include_defaults::Bool) where T
    if is_option(eltype(x))
        return map(p->to_dict(T, p, include_defaults), x)
    else
        return x
    end
end

function _option_to_dict(x, include_defaults)
    assert_option(x)

    d = OrderedDict{String, Any}()
    T = typeof(x)
    for name in fieldnames(T)
        type = fieldtype(T, name)
        value = getfield(x, name)
        if include_defaults || value != field_default(T, name)
            field_dict = to_dict(T, value, include_defaults)

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

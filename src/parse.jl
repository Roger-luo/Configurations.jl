"""
    from_dict(::Type{T}, d::AbstractDict{String}; kw...) where T

Convert dictionary `d` to an option type `T`, the valud of valid fields of `T`
in this dictionary `d` can be override by keyword arguments.

# Example

```julia-repl
julia> @option struct OptionA
           name::String = "Sam"
           age::Int = 25
       end

julia> d = Dict{String, Any}(
           "name" => "Roger",
           "age" => 10,
       );

julia> from_dict(OptionA, d; age=25)
OptionA(;
    name = "Roger",
    age = 25,
)
```
"""
function from_dict(::Type{T}, d::AbstractDict{String}; kw...) where T
    # override dict values
    d = from_underscore_kwargs!(deepcopy(d), T; kw...)
    return from_dict_validate(T, d)
end

"""
    from_toml(::Type{T}, filename::String; kw...) where T

Convert a given TOML file `filename` to an option type `T`. Valid fields
can be override by keyword arguments. See also [`from_dict`](@ref).
"""
function from_toml(::Type{T}, filename::String; kw...) where T
    is_option(T) || error("not an option type")
    d = TOML.parsefile(filename)
    d["#filename#"] = filename
    return from_dict(T, d; kw...)
end

"""
    from_toml_if_exists(::Type{T}, filename::String; kw...) where T

Similar to [`from_toml`](@ref) but will create the option instance
via `from_kwargs(T;kw...)` instead of error if the file does not exist.
"""
function from_toml_if_exists(::Type{T}, filename::String; kw...) where T
    if isfile(filename)
        return from_toml(T, filename; kw...)
    else
        return from_kwargs(T; kw...)
    end
end

"""
    from_kwargs(convention!, ::Type{T}; kw...) where T

Convert keyword arguments to given option type `T` using `convention!`.
See also [`from_dict`](@ref).

# Convention

- `from_underscore_kwargs!`: use `_` to disambiguate subfields of the same name, this is the default behaviour.
- `from_field_kwargs!`: do not disambiguate subfields, errors if there are disambiguity
"""
function from_kwargs(convention!, ::Type{T}; kw...) where T
    d = OrderedDict{String, Any}()
    convention!(d, T; kw...)
    return from_dict_validate(T, d)
end

"""
    from_kwargs(::Type{T}; kw...) where T

Convert keyword arguments to given option type `T` using the underscore convention.
"""
from_kwargs(::Type{T}; kw...) where T = from_underscore_kwargs(T; kw...)

"""
    from_underscore_kwargs(::Type{T}; kw...) where T

Convert keyword arguments to given option type `T` using the underscore convention.
"""
from_underscore_kwargs(::Type{T}; kw...) where T = from_kwargs(from_underscore_kwargs!, T; kw...)

"""
    from_field_kwargs(::Type{T}; kw...) where T

Convert keyword arguments to given option type `T` using the field keyword convention.
"""
from_field_kwargs(::Type{T}; kw...) where T = from_kwargs(from_field_kwargs!, T; kw...)

function from_dict_validate(::Type{T}, d::AbstractDict{String}) where T
    assert_option(T)

    for k in keys(d)
        k == "#filename#" && continue
        Symbol(k) in fieldnames(T) || error("invalid key: $k")
    end

    for (name, default) in zip(fieldnames(T), field_defaults(T))
        if default === no_default
            haskey(d, string(name)) && continue
            error("$name is required")
        end
    end

    return from_dict_inner(T, d)
end

function assert_union_alias(::Type{T}, name=nothing) where T
    T isa Union || return
    name === nothing && return
    name == type_alias(T.a) && error("duplicated alias name: $name")
    return assert_union_alias(T.b, type_alias(T.a))
end

# we don't process other kind of value
"""
    pick_union(::Type, x) -> type, value

Pick a type `T` and its corresponding value from a `Union`. For option
types it should be a dictionary type. The value can be furthur converted
to this type `T` via [`convert_to_option`](@ref) or `Base.convert`.
"""
pick_union(::Type{T}, x) where T = T, x

function pick_union(::Type{T}, d::AbstractDict{String}) where T
    if !(T isa Union)
        T === Nothing && return
        is_option(T) || return T, d
        if haskey(d, type_alias(T))
            return T, d[type_alias(T)]
        else
            return
        end
    end

    assert_union_alias(T)

    ret_a = pick_union(T.a, d)
    ret_b = pick_union(T.b, d)

    if ret_a === nothing
        return ret_b
    else
        return ret_a
    end
end

"""
    from_dict_inner(::Type{T}, d::AbstractDict{String}) where T

Internal method to convert a dictionary (subtype of `AbstractDict`)
to type `T`, this method will not check if `T` is an option type
via `is_option`, and will not validate if all the required fields
are available in the dict object.
"""
function from_dict_inner(::Type{T}, @nospecialize(d)) where T
    d isa AbstractDict{String} || error("cannot convert $d to $T, expect $T <: AbstractDict{String}")
    args = Any[]
    for each in fieldnames(T)
        key = string(each)
        type = fieldtype(T, each)
        default = field_default(T, each)
 
        if default === no_default
            if type isa Union
                pick = pick_union(type, d[key])
                pick === nothing && error("alias name for multi-option $type is required")
                type, value = pick
            else
                value = d[key]
            end
        else
            if type isa Union && haskey(d, key)
                pick = pick_union(type, d[key])
            else
                pick = nothing
            end

            if pick === nothing
                value = get(d, key, default)
            else
                type, value = pick
            end
        end

        if is_option(type) && value isa AbstractDict{String}
            # need some assertions so we call from_dict_validate
            push!(args, from_dict_validate(type, value))
        elseif value isa AbstractDict && isempty(value) && Nothing <: type
            # empty collection
            push!(args, nothing)
        else
            v = convert_union_to_option(T, type, value)
            if v === nothing
                push!(args, convert(type, value))
            else
                push!(args, v)
            end
        end
    end

    return T(args...)
end

# NOTE: this is for compatibilty
"""
    from_kwargs!(d::AbstractDict{String}, ::Type{T}, prefix::Maybe{Symbol} = nothing; kw...) where T

Internal method for inserting keyword arguments to given dictionary object `d`. It will overwrite
existing keys in `d` if it is specified by keyword argument.
"""
function from_kwargs!(d::AbstractDict{String}, ::Type{T}, prefix::Maybe{Symbol} = nothing; kw...) where T
    return from_underscore_kwargs!(d, T, prefix; kw...)
end

function from_underscore_kwargs!(d::AbstractDict{String}, ::Type{T}, prefix::Maybe{Symbol} = nothing; kw...) where T
    validate_keywords(T, underscore_keywords(T); kw...)
    unsafe_from_underscore_kwargs!(d, T, prefix; kw...)
end

function unsafe_from_underscore_kwargs!(d::AbstractDict{String}, ::Type{T}, prefix::Maybe{Symbol} = nothing; kw...) where T
    return foreach_keywords!(d, T) do name, type
        key = underscore(prefix, name)

        from_kwargs_option_key!(d, type, name, key, kw) do field_d, field_type
            unsafe_from_underscore_kwargs!(field_d, field_type, key; kw...)
        end
    end
end

function from_field_kwargs!(d::AbstractDict{String}, ::Type{T}; kw...) where T
    validate_keywords(T, field_keywords(T); kw...)
    unsafe_from_field_kwargs!(d, T; kw...)
end

function unsafe_from_field_kwargs!(d::AbstractDict{String}, ::Type{T}; kw...) where T
    return foreach_keywords!(d, T) do name, type
        from_kwargs_option_key!(d, type, name, name, kw) do field_d, field_type
            unsafe_from_field_kwargs!(field_d, field_type; kw...)
        end
    end
end

function from_kwargs_option_key!(f, d::AbstractDict, ::Type{T}, name::Symbol, key::Symbol, kw) where T
    key_str = string(key)
    name_str = string(name)
    # shortcut
    if haskey(kw, key)
        d[name_str] = kw[key]
        return d
    end
    
    if is_option(T)
        field_d = OrderedDict{String, Any}()
        if haskey(d, name_str)
            d[name_str] isa AbstractDict || error("option $key_str must be specified using an AbstractDict")
            field_d = merge!(field_d, d[name_str])
        end

        f(field_d, T) # recurse into subfields
        if !isempty(field_d)
            d[name_str] = field_d
        end
    elseif T isa Union
        from_kwargs_option_key!(f, d, T.a, name, key, kw)
        from_kwargs_option_key!(f, d, T.b, name, key, kw)
    end
    return d
end

function validate_keywords(::Type{T}, keys = underscore_keywords(T); kw...) where T
    if length(keys) > 8
        hint = join(map(x->LIGHT_BLUE_FG(string(x)), keys[1:8]), ", ")
        hint *= "... please check documentation for other valid keys"
    else
        hint = join(map(x->LIGHT_BLUE_FG(string(x)), keys), ", ")
    end

    for (k, v) in kw
        k in keys || throw(ArgumentError("invalid key $(LIGHT_BLUE_FG(string(k))), possible keys are: $hint"))
    end
    return
end

"""
    field_keywords(::Type{T}) where T

Return all the option type field names given `T`, error if there are duplicated sub-fields.
"""
function field_keywords(::Type{T}) where T
    return collect_field_keywords!(Symbol[], T)
end

"""
    underscore_keywords(::Type{T}) where T

Return keywords given `T` using the underscore convention.
"""
function underscore_keywords(::Type{T}) where T
    return collect_underscore_keywords!(Symbol[], T)
end

function foreach_keywords!(f, list, ::Type{T}) where T
    is_option(T) || return list

    for name in fieldnames(T)
        type = fieldtype(T, name)
        f(name, type)
    end
    return list
end

function underscore(prefix::Maybe{Symbol}, name)
    if prefix === nothing
        return name
    else
        return Symbol(prefix, :_, name)
    end
end

function collect_field_keywords!(list::Vector{Symbol}, ::Type{T}) where T
    return foreach_keywords!(list, T) do name, type
        msg = "duplicated field $(LIGHT_BLUE_FG(string(name))) " *
            "in type $(GREEN_FG(string(T))) and its sub-fields"
        if is_option(type)
            collect_field_keywords!(list, type)
        elseif type isa Union
            name in list && error(msg)
            push!(list, name)
            # recurse into Union
            collect_field_keywords!(list, type.a)
            collect_field_keywords!(list, type.b)
        else
            name in list && error(msg)
            push!(list, name)
        end
    end
end

function collect_underscore_keywords!(list::Vector{Symbol}, ::Type{T}, prefix::Maybe{Symbol} = nothing) where T
    return foreach_keywords!(list, T) do name, type
        key = underscore(prefix, name)

        if is_option(type)
            collect_underscore_keywords!(list, type, key)
        elseif type isa Union
            push!(list, key)
            collect_underscore_keywords!(list, type.a, key)
            collect_underscore_keywords!(list, type.b, key)
        else
            push!(list, key)
        end
    end
end

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
    validate_keywords(T; kw...)
    from_kwargs!(d, T; kw...)
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
    from_kwargs(::Type{T}; kw...) where T

Convert keyword arguments to given option type `T`. See also [`from_dict`](@ref).
"""
function from_kwargs(::Type{T}; kw...) where T
    validate_keywords(T; kw...)
    d = OrderedDict{String, Any}()
    from_kwargs!(d, T; kw...)
    return from_dict_validate(T, d)
end

function from_dict_validate(::Type{T}, d::AbstractDict{String}) where T
    is_option(T) || error("$T is not an option type")

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
to this type `T` via [`option_convert`](@ref) or `Base.convert`.
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
        key = haskey(d, key) ? key : field_alias(T, each)
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
            v = option_convert_union(T, type, value)
            if v === nothing
                push!(args, convert(type, value))
            else
                push!(args, v)
            end
        end
    end

    return T(args...)
end

"""
    from_kwargs!(d::AbstractDict{String}, ::Type{T}, prefix::Maybe{Symbol} = nothing; kw...) where T

Internal method for inserting keyword arguments to given dictionary object `d`. It will overwrite
existing keys in `d` if it is specified by keyword argument.
"""
function from_kwargs!(d::AbstractDict{String}, ::Type{T}, prefix::Maybe{Symbol} = nothing; kw...) where T
    if T isa Union
        from_kwargs!(d, T.a, prefix; kw...)
        from_kwargs!(d, T.b, prefix; kw...)
        return d
    end

    is_option(T) || return
    fnames = fieldnames(T)

    for name in fnames
        type = fieldtype(T, name)
        if prefix === nothing
            key = name
        else
            key = Symbol(prefix, :_, name)
        end

        if is_option(type) || type isa Union
            field_d = OrderedDict{String, Any}()
            from_kwargs!(field_d, type, key; kw...)
            if !isempty(field_d)
                d[string(name)] = field_d
            end
        elseif haskey(kw, key)
            d[string(name)] = kw[key]
        end
    end
    return d
end

function validate_keywords(::Type{T}; kw...) where T
    ks = keywords(T)
    hint = join(map(x->LIGHT_BLUE_FG(string(x)), ks), ", ")
    for (k, v) in kw
        k in ks || throw(ArgumentError("invalid key $(LIGHT_BLUE_FG(string(k))), possible keys are: $hint"))
    end
    return
end

"""
    keywords(::Type{T}) where T -> Vector{Symbol}

Get all the keywords of type `T`.
"""
keywords(::Type{T}) where T = collect_keywords!(Symbol[], T)

function collect_keywords!(list::Vector{Symbol}, ::Type{T}, prefix::Maybe{Symbol} = nothing) where T
    if T isa Union
        collect_keywords!(list, T.a, prefix)
        collect_keywords!(list, T.b, prefix)
        return list
    end

    is_option(T) || return list
    for name in fieldnames(T)
        type = fieldtype(T, name)
        if prefix === nothing
            key = name
        else
            key = Symbol(prefix, :_, name)
        end

        if is_option(type) || type isa Union
            collect_keywords!(list, type, key)
        else
            push!(list, key)
        end
    end
    return list
end

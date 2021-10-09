"""
    from_dict(::Type{T}, d::AbstractDict{String}; kw...) where T

Convert dictionary `d` to an option type `T`, the value of valid fields of `T`
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

function from_dict_validate(::Type{T}, d::AbstractDict{String}, root::Bool=true) where T
    assert_option(T)
    isconcretetype(T) || throw(ArgumentError("expect concrete type, got $T"))

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

    return from_dict_inner(T, d, root)
end

struct DuplicatedAliasError <: Exception
    name::String
end

function Base.show(io::IO, err::DuplicatedAliasError)
    print(io, "duplicated alias name: ")
    printstyled(io, err.name; color=:cyan)
end

function assert_union_alias(::Type{T}) where T
    T isa Union || return
    collect_assert_type_alias!(String[], T)
    return
end

function collect_assert_type_alias!(list::Vector{String}, ::Type{T}) where T
    if T isa Union
        collect_assert_type_alias!(list, T.a)
        collect_assert_type_alias!(list, T.b)
    else
        is_option(T) || return list
        alias = type_alias(T)
        alias in list && throw(DuplicatedAliasError(alias))
        alias === nothing || push!(list, alias)
    end
    return list
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

        # if the option struct contains Reflect field
        # we will use this field to address type info
        # which supersedes type alias
        for idx in 1:fieldcount(T)
            if fieldtype(T, idx) === Reflect
                return pick_union_reflect_type(T, idx, d)
            end
        end

        is_option(T) || return T, d
        if haskey(d, type_alias(T))
            return T, d[type_alias(T)]
        else
            return
        end
    end

    assert_union_alias(T)

    ret_a = pick_union(T.a, d)
    if ret_a === nothing
        ret_b = pick_union(T.b, d)
        return ret_b
    else
        return ret_a
    end
end

function pick_union_reflect_type(::Type{T}, reflect_field_idx::Int, d::AbstractDict{String}) where T
    reflected_field = fieldname(T, reflect_field_idx)
    reflected_field_str = string(reflected_field)
    haskey(d, reflected_field_str) || return
    type = parse_jltype(d[reflected_field_str])
    d[reflected_field_str] = Reflect()
    return type, d
end

function parse_jltype(s)
    s isa String || throw(ArgumentError("expect type String, got: $(typeof(s))"))
    type_ex = Meta.parse(s)
    # is_datatype_expr(type_ex) || throw(ArgumentError("expect type expression got: $type_ex"))
    return eval(type_ex)
end

"""
    from_dict_inner(::Type{T}, d::AbstractDict{String}) where T

Internal method to convert a dictionary (subtype of `AbstractDict`)
to type `T`, this method will not check if `T` is an option type
via `is_option`, and will not validate if all the required fields
are available in the dict object.
"""
function from_dict_inner(::Type{T}, @nospecialize(d), root::Bool=false) where T
    d isa AbstractDict{String} || error("cannot convert $d to $T, expect $T <: AbstractDict{String}")

    if contains_reflect_type(T) && root
        # NOTE: for 1.0 compat
        idx = findfirst(x->x === Reflect, fieldtypes(T))
        key = string(fieldname(T, idx))
        haskey(d, key) || throw(ArgumentError("expect key: $key"))

        value = d[key]
        dst_type = parse_jltype(value)
        dst_type <: T || throw(ArgumentError("type mismatch, expect $T got $value"))
    else
        dst_type = T
    end

    args = Any[]
    for each in fieldnames(dst_type)
        key = string(each)
        type = fieldtype(dst_type, each)
        default = field_default(dst_type, each)

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
            push!(args, from_dict_validate(type, value, false))
        elseif value isa AbstractDict && isempty(value) && Nothing <: type
            # empty collection
            push!(args, nothing)
        elseif type === Reflect
            push!(args, Reflect())
        else
            v = convert_union_to_option(dst_type, type, value)
            push!(args, v)
        end
    end

    return dst_type(args...)
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
        if haskey(d, name_str) && (d_value = d[name_str]) isa AbstractDict
            field_d = merge!(field_d, d_value)
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

struct InvalidKeyError <: Exception
    got::Symbol
    keys::Vector{Symbol}
end

function Base.show(io::IO, err::InvalidKeyError)
    print(io, "invalid key ")
    printstyled(io, err.got; color=:light_blue)
    print(io, ", possible keys are: ")

    if length(err.keys) > 8
        for idx in 1:8
            printstyled(io, err.keys[idx]; color=:light_blue)
            if idx != 8
                print(io, ", ")
            end
        end
        print(io, "... please check documentation for other valid keys")
    else
        for idx in eachindex(err.keys)
            printstyled(io, err.keys[idx]; color=:light_blue)
            if idx != lastindex(err.keys)
                print(io, ", ")
            end
        end
    end
    return
end

function validate_keywords(::Type{T}, keys = underscore_keywords(T); kw...) where T
    for (k, v) in kw
        k in keys || throw(InvalidKeyError(k, keys))
    end
    return
end

"""
    field_keywords(::Type{T}) where T

Return all the option type field names given `T`, error if there are duplicated sub-fields.
"""
function field_keywords(::Type{T}) where T
    return collect_field_keywords!(Symbol[], T, T)
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

"""
    DuplicatedFieldError(name, type)

A field with `name` of given option `type` is duplicated in the subfields option type.
Thus one cannot use the field keyword convention when seeing this error.
"""
struct DuplicatedFieldError <: Exception
    name::Symbol
    type
end

function Base.show(io::IO, err::DuplicatedFieldError)
    print(io, "duplicated field ")
    printstyled(io, err.name; color=:light_blue)
    print(io, " in type ")
    printstyled(io, err.type; color=:green)
    print(io, " and its sub-fields")
end

function collect_field_keywords!(list::Vector{Symbol}, ::Type{Top}, ::Type{T}) where {Top, T}
    return foreach_keywords!(list, T) do name, type
        if is_option(type)
            collect_field_keywords!(list, Top, type)
        elseif type isa Union
            name in list && error(msg)
            push!(list, name)
            # recurse into Union
            collect_field_keywords!(list, Top, type.a)
            collect_field_keywords!(list, Top, type.b)
        else
            name in list && throw(DuplicatedFieldError(name, Top))
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

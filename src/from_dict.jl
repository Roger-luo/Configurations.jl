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
function from_dict(::Type{OptionType}, d::AbstractDict{String}; kw...) where {OptionType}
    if !isempty(kw)
        d = from_underscore_kwargs!(deepcopy(d), OptionType; kw...)
    end
    return from_dict_dynamic(OptionType, d)
end

struct OptionField{name} end
OptionField(name::Symbol) = OptionField{name}()

function from_dict(::Type{OptionType}, ::OptionField, ::Type{T}, x) where {OptionType, T}
    return from_dict(OptionType, T, x)
end

function from_dict(::Type{OptionType}, ::OptionField{field}, ::Type{T}, x) where {OptionType, field, T <: AbstractVector}
    if eltype(T) isa Union
        return map(x) do each
            from_dict_union_type(OptionType, field, eltype(T), each)
        end
    elseif is_option(eltype(T))
        return map(x) do each
            from_dict_option_type(OptionType, field, eltype(T), each)
        end
    else
        return map(x) do each
            from_dict_other_type(OptionType, field, eltype(T), each)
        end
    end
end

function from_dict(::Type{OptionType}, ::Type{T}, x) where {OptionType, T}
    is_option(T) && return from_dict(T, x)
    # TODO: deprecate convert_to_option
    # then just use the following
    # return convert(T, x)
    return deprecated_conversion(OptionType, T, x)
    # return convert(T, x)
end

from_dict(::Type, ::Type{VersionNumber}, x) = VersionNumber(x)

function deprecated_conversion(::Type{OptionType}, ::Type{T}, x) where {OptionType, T}
    ret = convert_to_option(OptionType, T, x)
    if ret === ConvertNotFound()
        return convert(T, x)
    else
        return ret
    end
end

function from_dict_dynamic(::Type{OptionType}, d::AbstractDict{String}) where {OptionType}
    isconcretetype(OptionType) || throw(ArgumentError("expect concrete type, got $OptionType"))

    nf = fieldcount(OptionType)
    args = ntuple(nf) do f_idx
        f_name = fieldname(OptionType, f_idx)
        f_type = fieldtype(OptionType, f_idx)
        f_default = field_default(OptionType, f_name)
        key = string(f_name)
        if !haskey(d, key)
            f_default === no_default && error("expect key: $key")
            return f_default
        end

        value = d[key]
        # empty dict is treated as nothing
        if value isa AbstractDict && isempty(value) && f_default === nothing
            return nothing
        end

        return if is_option(f_type)
            from_dict_option_type(OptionType, f_name, f_type, value)
        elseif f_type isa Union
            from_dict_union_type(OptionType, f_name, f_type, value)
        elseif f_type <: Reflect
            type_alias(OptionType) == value || parse_jltype(value) <: OptionType ||
                throw(ArgumentError("type mismatch, expect $OptionType got $value"))
            Reflect()
        else
            from_dict_other_type(OptionType, f_name, f_type, value)
        end
    end
    return OptionType(args...)
end

function from_dict_option_type(::Type{OptionType}, f_name::Symbol, ::Type{T}, value) where {OptionType, T}
    value isa AbstractDict || error("expect an AbstractDict, got $(typeof(value))")
    return from_dict_dynamic(T, value)
end

function from_dict_other_type(::Type{OptionType}, f_name::Symbol, ::Type{T}, value) where {OptionType, T}
    return from_dict(OptionType, OptionField(f_name), T, value)
end

function from_dict_union_type(::Type{OptionType}, f_name::Symbol, ::Type{FieldType}, value) where {OptionType, FieldType}
    assert_duplicated_alias_union(FieldType)

    for T in Base.uniontypes(FieldType)
        if is_option(T)
            alias = type_alias(T)
            reflect_idx = find_relfect_field(T)
            # type can be determined by alias
            if haskey(value, alias)
                return from_dict_dynamic(T, value[alias])
            elseif reflect_idx !== nothing # type can be determined by reflect field
                reflect_f_name = fieldname(T, reflect_idx)
                reflect_key = string(reflect_f_name)
                if haskey(value, reflect_key)
                    if alias == value[reflect_key] # find alias in reflect
                        return from_dict_dynamic(T, value)
                    else
                        type = tryparse_jltype(value[reflect_key])
                        type === nothing && continue
                        # NOTE: type is always more specialized
                        type <: T && return from_dict_dynamic(type, value)
                    end
                end
                continue
            end

            if alias === nothing && reflect_idx === nothing
                # not much information, try parse
                try
                    return from_dict_dynamic(T, value)
                catch
                    continue
                end
            end
        else
            try
                return from_dict(OptionType, OptionField(f_name), T, value) 
            catch
                continue
            end
        end
    end
    error("cannot parse field $f_name, expect $FieldType, got $(typeof(value))")
end

function find_relfect_field(::Type{OptionType}) where {OptionType}
    nf = fieldcount(OptionType)
    for f_idx in 1:nf
        f_type = fieldtype(OptionType, f_idx)
        if f_type <: Reflect
            return f_idx
        end
    end
    return
end

function assert_duplicated_alias_union(::Type{UnionType}) where {UnionType}
    set = String[]
    for T in Base.uniontypes(UnionType)
        if is_option(T)
            alias = type_alias(T)
            if alias !== nothing
                alias in set && throw(DuplicatedAliasError(alias))
                push!(set, alias)
            end
        end
    end
    return
end

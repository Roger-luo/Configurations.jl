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
    isconcretetype(OptionType) || throw(ArgumentError("expect a concrete type, got $OptionType"))
    if !isempty(kw)
        d = from_underscore_kwargs!(deepcopy(d), OptionType; kw...)
    end
    return from_dict_specialize(OptionType, d)
end

struct OptionField{name} end
OptionField(name::Symbol) = OptionField{name}()

function from_dict(::Type{OptionType}, ::OptionField, ::Type{T}, x) where {OptionType, T}
    return from_dict(OptionType, T, x)
end

function from_dict(::Type{OptionType}, of::OptionField, ::Type{T}, x) where {OptionType, T <: AbstractVector}
    if eltype(T) isa Union
        return map(x) do each
            from_dict_union_type(OptionType, of, eltype(T), each)
        end
    else
        return map(x) do each
            from_dict(OptionType, of, eltype(T), each)
        end
    end
end

# default conversions
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

# function from_dict_dynamic(::Type{OptionType}, d::AbstractDict{String}) where {OptionType}
#     isconcretetype(OptionType) || throw(ArgumentError("expect concrete type, got $OptionType"))

#     nf = fieldcount(OptionType)
#     args = ntuple(nf) do f_idx
#         f_name = fieldname(OptionType, f_idx)
#         f_type = fieldtype(OptionType, f_idx)
#         f_default = field_default(OptionType, f_name)
#         key = string(f_name)
#         if !haskey(d, key)
#             f_default === no_default && error("expect key: $key")
#             return f_default
#         end

#         value = d[key]
#         # empty dict is treated as nothing
#         if value isa AbstractDict && isempty(value) && f_default === nothing
#             return nothing
#         end

#         return if is_option(f_type)
#             from_dict_option_type(OptionType, f_name, f_type, value)
#         elseif f_type isa Union
#             from_dict_union_type(OptionType, f_name, f_type, value)
#         elseif f_type <: Reflect
#             type_alias(OptionType) == value || parse_jltype(value) <: OptionType ||
#                 throw(ArgumentError("type mismatch, expect $OptionType got $value"))
#             Reflect()
#         else
#             from_dict_other_type(OptionType, f_name, f_type, value)
#         end
#     end
#     return OptionType(args...)
# end

# function from_dict_option_type(::Type{OptionType}, f_name::Symbol, ::Type{T}, value) where {OptionType, T}
#     value isa AbstractDict || error("expect an AbstractDict, got $(typeof(value))")
#     return from_dict_dynamic(T, value)
# end

# function from_dict_other_type(::Type{OptionType}, f_name::Symbol, ::Type{T}, value) where {OptionType, T}
#     return from_dict(OptionType, OptionField(f_name), T, value)
# end

@generated function from_dict_union_type(::Type{OptionType}, ::OptionField{f_name}, ::Type{FieldType}, value) where {OptionType, f_name, FieldType}
    types = Base.uniontypes(FieldType)
    return from_dict_union_type_generated(OptionType, OptionField(f_name), types, :value)
end

function from_dict_union_type_dynamic(::Type{OptionType}, of::OptionField{f_name}, ::Type{FieldType}, value) where {OptionType, f_name, FieldType}
    assert_duplicated_alias_union(FieldType)

    for T in Base.uniontypes(FieldType)
        if is_option(T)
            alias = type_alias(T)
            reflect_idx = find_reflect_field(T)
            # type can be determined by alias
            if haskey(value, alias)
                return from_dict(T, value[alias])
            elseif reflect_idx !== nothing # type can be determined by reflect field
                reflect_f_name = fieldname(T, reflect_idx)
                reflect_key = string(reflect_f_name)
                if haskey(value, reflect_key)
                    if alias == value[reflect_key] # find alias in reflect
                        return from_dict(T, value)
                    else
                        type = tryparse_jltype(value[reflect_key])
                        type === nothing && continue
                        # NOTE: type is always more specialized
                        type <: T && return from_dict(type, value)
                    end
                end
                continue
            end

            if alias === nothing && reflect_idx === nothing
                # not much information, try parse
                try
                    return from_dict(T, value)
                catch
                    continue
                end
            end
        else
            try
                return from_dict(OptionType, of, T, value)
            catch
                continue
            end
        end
    end
    error("cannot parse field $f_name, expect $FieldType, got $(typeof(value))")
end

function find_reflect_field(::Type{OptionType}) where {OptionType}
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

function from_dict_specialize
end

function from_dict_generated(::Type{OptionType}, value) where {OptionType}
    nf = fieldcount(OptionType)
    ret = Expr(:block)
    construct = Expr(:call, OptionType)
    for f_idx in 1:nf
        f_name = fieldname(OptionType, f_idx)
        f_type = fieldtype(OptionType, f_idx)
        f_default = field_default(OptionType, f_name)

        var = gensym(f_name)
        key = string(f_name)
        field_value = gensym(:field_value)
        push!(construct.args, var)

        jl = JLIfElse()

        if f_default === no_default
            jl[:(!haskey($value, $key))] = :(error("expect key: $key"))
        else
            jl[:(!haskey($value, $key))] = :($var = $f_default)
        end

        body = from_dict_generated(OptionType, OptionField(f_name), f_type, field_value)
        if f_default === nothing
            jl.otherwise = quote
                $field_value = $value[$key]
                if $field_value isa AbstractDict && isempty($field_value)
                    $var = nothing
                else
                    $var = $body
                end
            end
        else
            jl.otherwise = quote
                $field_value = $value[$key]
                $var = $body
            end
        end

        push!(ret.args, codegen_ast(jl))
    end
    push!(ret.args, construct)
    return ret
end

function from_dict_generated(option_type, of::OptionField, f_type, field_value)
    if is_option(f_type)
        quote
            $field_value isa AbstractDict ||
                error("expect an AbstractDict, got $(typeof($field_value))")
            # NOTE: we want to allow user overloaded from_dict here
            # thus we don't use $(from_dict_generated(f_type, value))
            $Configurations.from_dict($f_type, $field_value)
        end
    elseif f_type isa Union
        types = Base.uniontypes(f_type)
        from_dict_union_type_generated(option_type, of, types, field_value)
    elseif f_type <: Reflect # check if the reflect value match current type
        msg = "type mismatch, expect $option_type got"
        alias = type_alias(option_type)
        if alias === nothing
            quote
                $Configurations.parse_jltype($field_value) <: $option_type ||
                    throw(ArgumentError($msg * " $($field_value)"))
                Reflect()
            end
        else
            quote
                $field_value == $alias || $Configurations.parse_jltype($field_value) <: $option_type ||
                    throw(ArgumentError($msg * " $($field_value)"))
                Reflect()
            end
        end
    else
        quote
            $Configurations.from_dict($option_type, $of, $f_type, $field_value)
        end
    end
end

function from_dict_union_type_generated(option_type, of::OptionField, types::Vector{Any}, value::Symbol)
    if Nothing in types
        from_dict_maybe_type_generated(option_type, of, types, value)
    elseif has_same_reflect_field(types)
        _from_dict_union_type_similar_reflect_field(types, value)
    else # fallback to dynamic
        FieldType = Union{types...}
        return quote
            $Configurations.from_dict_union_type_dynamic($option_type, $of, $FieldType, $value)
        end
    end
end

function from_dict_maybe_type_generated(option_type, of::OptionField, types::Vector{Any}, value)
    types = filter(x -> x !== Nothing, types)
    if length(types) == 1 # Maybe{T}
        return quote
            if $value === nothing
                nothing
            else
                $(from_dict_generated(option_type, of, types[1], value))
            end
        end
    else # Maybe{Union{A, B, C...}}
        return quote
            if $value === nothing
                nothing
            else
                $(from_dict_union_type_generated(option_type, of, types, value))
            end
        end
    end
end

function _from_dict_union_type_similar_reflect_field(types, value)
    T = first(types)
    f_alias_map = alias_map(types)
    f_alias_map = isempty(f_alias_map) ? nothing : f_alias_map
    idx = find_reflect_field(T)
    reflect_key = string(fieldname(T, idx))
    msg = "expect key: $reflect_key"

    @gensym type
    return quote
        haskey($value, $reflect_key) || error($msg)
        $type = $Configurations.parse_jltype($value[$reflect_key], $f_alias_map)
        $Configurations.from_dict_specialize($type, $value)
    end
end

function has_same_reflect_field(types)
    idx = find_reflect_field(first(types))
    idx === nothing && return false

    f_reflect = fieldname(first(types), idx)
    for t_idx in 2:length(types)
        T = types[t_idx]
        t_reflect_idx = find_reflect_field(T)
        t_reflect_idx === nothing && return false

        t_f_reflect = fieldname(T, t_reflect_idx)
        if f_reflect !== t_f_reflect
            return false
        end
    end
    return true
end

function alias_map(types)
    d = Dict{String, Any}()
    for t in types
        if is_option(t)
            alias = type_alias(t)
            if alias !== nothing
                d[alias] = t
            end
        end
    end
    return d
end

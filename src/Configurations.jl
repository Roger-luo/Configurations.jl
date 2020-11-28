module Configurations

export @option, from_dict, from_kwargs, from_toml, to_dict, to_toml

using OrderedCollections
using MatchCore
using Crayons.Box
using ExprTools
using TOML

struct NoDefault end

const no_default = NoDefault()
const Maybe{T} = Union{Nothing, T}

function field_defaults(::Type{T}) where T
    error("$T is not an option type")
end

function alias(::Type{T}) where T
    error("$T is not an option type")
end

"""
    to_dict(option) -> OrderedDict

Convert an option to an `OrderedDict`.
"""
function to_dict(x)
    is_option(x) || error("argument is not an option type")
    return dictionalize(x)
end

function to_toml(x)
    d = to_dict(x)
    return sprint(TOML.print, d)
end

function dictionalize(x)
    is_option(x) || return x
    d = OrderedDict{String, Any}()
    for name in fieldnames(typeof(x))
        value = dictionalize(getfield(x, name))
        if value !== nothing
            d[string(name)] = value
        end
    end
    return d
end

is_option(x) = false

function from_dict(::Type{T}, d::AbstractDict{String}; kw...) where T
    # override dict values
    validate_keywords(T; kw...)
    from_kwargs!(d, T; kw...)
    return from_dict_validate(T, d)
end

function from_dict_validate(::Type{T}, d::AbstractDict{String}) where T
    is_option(T) || error("$T is not an option type")

    for k in keys(d)
        Symbol(k) in fieldnames(T) || error("invalid key: $k")
    end

    for (name, default) in zip(fieldnames(T), field_defaults(T))
        if default === no_default
            haskey(d, string(name)) || error("$name is required")
        end
    end

    return from_dict_inner(T, d)
end

function from_dict_inner(::Type{T}, x) where T
    error("cannot convert $x to $T")
end

function assert_union_alias(::Type{T}, name=nothing) where T
    T isa Union || return
    name === nothing && return
    name == alias(T.a) && error("duplicated alias name: $name")
    return assert_union_alias(T.b, alias(T.a))
end

# we don't process other kind of value
pick_union(::Type{T}, x) where T = T, x

function pick_union(::Type{T}, d::AbstractDict{String}) where T
    if !(T isa Union)
        is_option(T) || return T, d
        if haskey(d, alias(T))
            return T, d[alias(T)]
        else
            return
        end
    end
    
    assert_union_alias(T)
    if is_option(T.a) && alias(T.a) !== nothing && haskey(d, alias(T.a))
        return T.a, d[alias(T.a)]
    else
        return pick_union(T.b, d)
    end
end

function from_dict_inner(::Type{T}, d::AbstractDict{String}) where T
    args = Any[]
    for (each, default) in zip(fieldnames(T), field_defaults(T))
        key = string(each)
        type = fieldtype(T, each)
 
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
            # need some assertions so we call from_dict
            push!(args, from_dict_validate(type, value))
        else
            push!(args, value)
        end
    end

    return T(args...)
end

function from_toml(::Type{T}, filename::String; kw...) where T
    is_option(T) || error("not an option type")
    return from_dict(T, TOML.parsefile(filename); kw...)
end

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

function from_kwargs(::Type{T}; kw...) where T
    validate_keywords(T; kw...)
    d = OrderedDict{String, Any}()
    from_kwargs!(d, T; kw...)
    return from_dict_validate(T, d)
end

struct Field
    name::Symbol
    type::Any
    default::Any
    line
end

struct OptionDef
    name::Symbol
    alias::Union{Nothing, String}
    ismutable::Bool
    parameters::Vector{Any}
    supertype

    fields::Vector{Field}
    misc::Vector{Any}

    function OptionDef(name, alias, ismutable, params, supertype, fields::Vector{Field}, misc)
        for each in fields
            if each.name == alias
                error("fieldname is the same as alias name")
            end
        end
        new(name, alias, ismutable, params, supertype, fields, misc)
    end
end

function Base.show(io::IO, x::Field)
    indent = get(io, :indent, 0)
    print(io, " "^indent, x.name)

    if x.type !== Any
        print(io, "::", GREEN_FG(string(x.type)))
    end

    if x.default !== no_default
        print(io, " = ", x.default)
    end
end

function Base.show(io::IO, x::OptionDef)
    indent = get(io, :indent, 0)

    if x.ismutable
        print(io, " "^indent, BLUE_FG("mutable "))
    end

    print(io, BLUE_FG("struct"))
    print(io, " ", x.name)
    if !isempty(x.parameters)
        print(io, "{", DARK_GRAY_FG(join(string.(x.parameters), ", ")), "}")
    end

    if x.supertype !== nothing
        print(io, " <: ", GREEN_FG(string(x.supertype)))
    end

    println(io)
    let io = IOContext(io, :indent=>indent+2)
        for (k, each) in enumerate(x.fields)
            println(io, each)
        end
    end

    print(io, " "^indent, BLUE_FG("end"))
end

function OptionDef(@nospecialize(ex), alias=nothing)
    ex isa Expr || error("invalid usage of @option")
    ex.head === :struct || error("invalid usage of @option")

    name, parameters, supertype = split_name(ex)
    fields, misc = split_body(ex)
    return OptionDef(name, alias, ex.args[1], parameters, supertype, fields, misc)
end

function split_name(ex::Expr)
    T = ex.args[2]

    return @smatch T begin
        :($name{$(params...)}) => (name, params, nothing)
        :($name{$(params...)} <: $type) => (name, params, type)
        ::Symbol => (T, [], nothing)
        :($name <: $type) => (name, [], type)
        _ => error("invalid @option: $ex")
    end
end

function split_body(ex::Expr)
    body = ex.args[3]
    body.head === :block || error("expect a block, got $ex")

    fields = Field[]
    misc = Any[]
    line = nothing

    for each in body.args
        item = @smatch each begin
            :($name::$type = $default) => Field(name, type, default, line)

            :($name::$type) => Field(name, type, no_default, line)

            :($name = $default) => Field(name, Any, default, line)

            ::Symbol => Field(each, Any, no_default, line)

            ::LineNumberNode => begin
                line = each
            end

            _ => begin
                push!(misc, line)
                push!(misc, each)
                nothing
            end
        end

        if item isa Field
            push!(fields, item)
        end
    end
    return fields, misc
end

function codegen_struct_def(x::OptionDef)
    T = x.name

    if !isempty(x.parameters)
        T = Expr(:curly, T, x.parameters...)
    end

    if x.supertype !== nothing
        T = Expr(:(<:), T, x.supertype)
    end

    body = Expr(:block)
    for each in x.fields
        if each.line !== nothing
            push!(body.args, each.line)
        end

        if each.type === Any
            item = each.name
        else
            item = :($(each.name)::$(each.type))
        end
        push!(body.args, item)
    end

    for each in x.misc
        push!(body.args, each)
    end
    return Expr(:struct, x.ismutable, T, body)
end

function codegen_kw_fn(x::OptionDef)
    kwargs = []
    for each in x.fields
        if each.default === no_default
            push!(kwargs, each.name)
        else
            push!(kwargs, Expr(:kw, each.name, each.default))
        end
    end
    
    def = Dict(
        :name => x.name,
        :kwargs => kwargs,
        :body => Expr(:call, x.name, [each.name for each in x.fields]...)
    )
    return combinedef(def)
end

option_print(io::IO, m::MIME, x) = show(io, m, x)
option_print(io::IO, ::MIME, x::AbstractDict) = show(io, x)

function option_print(io::IO, m::MIME"text/plain", x::AbstractDict{String})
    indent = get(io, :indent, 0)
    println(io, typeof(x), "(")
    for (k, v) in x
        print(io, " "^(indent+4), LIGHT_BLUE_FG("\"", k, "\""), " => ")
        option_print(IOContext(io, :indent=>(indent+4)), m, v)
        println(io, ",")
    end
    print(io, " "^indent, ")")
end

# inline printing arrays
option_print(io::IO, ::MIME, x::AbstractArray) = show(io, x)

function codegen_show_text(x::OptionDef)
    body = quote
        indent = get(io, :indent, 0)
        println(io, $(GREEN_FG(string(x.name))), "(;")
    end

    for each in x.fields
        push!(body.args, :( print(io, " "^(indent+4), $(LIGHT_BLUE_FG(string(each.name))), " = ") ))
        push!(body.args, :( $(GlobalRef(Configurations, :option_print))(IOContext(io, :indent=>(indent+4)), m, x.$(each.name)) ))
        push!(body.args, :( println(io, ",") ))
    end
    
    push!(body.args, :(print(io, " "^indent, ")")))

    def = Dict(
        :name => GlobalRef(Base, :show),
        :args => [:(io::IO), :(m::MIME"text/plain"), :(x::$(x.name))],
        :body => body,
    )

    return combinedef(def)
end

function codegen_is_option(x::OptionDef)
    quote
        $(GlobalRef(Configurations, :is_option))(::$(x.name)) = true
        $(GlobalRef(Configurations, :is_option))(::Type{<:$(x.name)}) = true
    end
end

function codegen_convert(x::OptionDef)
    :(Base.convert(::Type{<:$(x.name)}, d::AbstractDict{String}) = $(GlobalRef(Configurations, :from_dict))($(x.name), d))
end

function codegen_field_defaults(x::OptionDef)
    defaults = Expr(:ref, Any)
    for each in x.fields
        push!(defaults.args, each.default)
    end

    def = Dict(
        :name => GlobalRef(Configurations, :field_defaults),
        :args => [:(::Type{<:$(x.name)})],
        :body => defaults
    )

    return combinedef(def)
end

function codegen_alias(x::OptionDef)
    def = Dict(
        :name => GlobalRef(Configurations, :alias),
        :args => [:(::Type{<:$(x.name)})],
        :body => x.alias
    )
    return combinedef(def)
end

compare_options(a, b) = false

function compare_options(a::A, b::A) where {A}
    for each in fieldnames(A)
        getfield(a, each) == getfield(b, each) || return false
    end
    return true
end

function codegen_isequal(x::OptionDef)
    return :(Base.:(==)(a::$(x.name), b::$(x.name)) = $compare_options(a, b))
end

function option_m(@nospecialize(ex), alias=nothing)
    def = OptionDef(ex, alias)

    quote
        $(codegen_struct_def(def))
        Core.@__doc__ $(def.name)
        $(codegen_kw_fn(def))
        $(codegen_convert(def))
        $(codegen_show_text(def))
        $(codegen_is_option(def))
        $(codegen_field_defaults(def))
        $(codegen_alias(def))
        $(codegen_isequal(def))
        nothing
    end
end

"""
    @option <struct def>

Define an option struct type. This will auto-generate methods that parse a given `Dict{String}`
object (the keys must be of type `String`) into an instance of the struct type you defined.

# Example

```julia
julia> @option struct OptionA
           name::String
           int::Int = 1
       end

julia> @option struct OptionB
           opt::OptionA = OptionA(;name = "Sam")
           float::Float64 = 0.3
       end

julia> d = Dict(
           "opt" => Dict(
               "name" => "Roger",
               "int" => 2,
           ),
           "float" => 0.33
       )
Dict{String, Any} with 2 entries:
  "opt"   => Dict{String, Any}("int"=>2, "name"=>"Roger")
  "float" => 0.33

julia> OptionB(d)
OptionB(;
  opt = OptionA(;
    name = "Roger",
    int = 2,
  ),
  float = 0.33,
)
```
"""
macro option(ex)
    esc(option_m(ex))
end

macro option(alias::String, ex)
    esc(option_m(ex, alias))
end

end

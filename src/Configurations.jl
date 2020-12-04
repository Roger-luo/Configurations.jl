module Configurations

export @option, from_dict, from_kwargs, from_toml, to_dict, to_toml

using OrderedCollections
using MatchCore
using Crayons.Box
using ExprTools
using TOML

struct NoDefault end

"const for non default fields"
const no_default = NoDefault()

"maybe of type `T` or nothing"
const Maybe{T} = Union{Nothing, T}

"""
    field_defaults(::Type)

Return default values of given option types.
"""
function field_defaults(::Type{T}) where T
    is_option(T) || error("$T is not an option type")
    return Any[field_default(T, each) for each in fieldnames(T)]
end

"""
    field_default(::Type{T}, name::Symbol)

Return the default value of field `name` of an option type `T`.
"""
function field_default(::Type{T}, name::Symbol) where {T}
    error("$T is not an option type")
end

function alias(::Type{T}) where T
    error("$T is not an option type")
end

"""
    option_convert(::Type{OptionType}, ::Type{ValueType}, x) where {OptionType, ValueType}

Convert `x` to type `ValueType` for option type `OptionType`. This is similar to `Base.convert`,
but one can use this to avoid type piracy.
"""
option_convert(::Type, ::Type{A}, x) where {A} = convert(A, x)

"""
    to_dict(option) -> OrderedDict

Convert an option to an `OrderedDict`.
"""
function to_dict(x)
    is_option(x) || error("argument is not an option type")
    return dictionalize(x)
end

"""
    to_toml(x; sorted=false, by=identity)

Convert an instance `x` of option type to TOML and write it to `String`. See also `TOML.print`.
"""
function to_toml(x; sorted=false, by=identity)
    return sprint(to_toml, x)
end

function to_toml(io, x; sorted=false, by=identity)
    return to_toml(identity, io, x; sorted=sorted, by=by)
end

"""
    to_toml([to_toml::Function], filename::String, option; sorted=false, by=identity)

Convert an instance `option` of option type to TOML and write it to `filename`. See also `TOML.print`.
"""
function to_toml(f, filename::String, x; sorted=false, by=identity)
    open(filename, "w+") do io
        to_toml(f, io, x; sorted=sorted, by=by)
    end
end

"""
    to_toml([to_toml::Function], io::IO [=stdout], option; sorted=false, by=identity)

Convert an instance `option` of option type to TOML and write it to `IO`. See also `TOML.print`.
"""
function to_toml(f, io::IO, x; sorted=false, by=identity)
    return TOML.print(f, io, to_dict(x); sorted=sorted, by=by)
end

"""
    dictionalize(x)

Convert `x` to an `OrderedDict`.
"""
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

"""
    is_option(x)

Check if `x` is an option type or not.
"""
is_option(x) = false

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
"""
    pick_union(::Type, x) -> type, value

Pick a type `T` and its corresponding value from a `Union`. For option
types it should be a dictionary type. The value can be furthur converted
to this type `T` via [`option_convert`](@ref) or `Base.convert`.
"""
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

"""
    from_dict_inner(::Type{T}, d::AbstractDict{String}) where T

Internal method to convert a dictionary (subtype of `AbstractDict`)
to type `T`, this method will not check if `T` is an option type
via `is_option`, and will not validate if all the required fields
are available in the dict object.
"""
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
            # need some assertions so we call from_dict_validate
            push!(args, from_dict_validate(type, value))
        else
            push!(args, option_convert(T, type, value))
        end
    end

    return T(args...)
end

"""
    from_toml(::Type{T}, filename::String; kw...) where T

Convert a given TOML file `filename` to an option type `T`. Valid fields
can be override by keyword arguments. See also [`from_dict`](@ref).
"""
function from_toml(::Type{T}, filename::String; kw...) where T
    is_option(T) || error("not an option type")
    return from_dict(T, TOML.parsefile(filename); kw...)
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

"""
    Field

Type to represent a field definition in option type.
"""
struct Field
    name::Symbol
    type::Any
    default::Any
    line
end

"""
    OptionDef

Type to represent the option type definition.
"""
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

function has_custom_kw_fn(def::OptionDef)
    return has_custom_kw_fn(def.misc)
end

function has_custom_kw_fn(misc::Vector{Any})
    for each in misc
        is_kw_fn(each) && return true
    end
    return false
end

is_kw_fn(x) = false

# TODO: implement this directly without splitdef
function is_kw_fn(ex::Expr)
    def = splitdef(ex; throw=false)
    def === nothing && return false
    haskey(def, :args) && return false
    return haskey(def, :kwargs)
end

"""
    split_name(ex::Expr) -> name, typevars, supertype

Split the name, type parameters and supertype definition from `struct`
declaration head.
"""
function split_name(ex::Expr)
    T = ex.args[2]

    return @smatch T begin
        :($name{$(typevars...)}) => (name, typevars, nothing)
        :($name{$(typevars...)} <: $type) => (name, typevars, type)
        ::Symbol => (T, [], nothing)
        :($name <: $type) => (name, [], type)
        _ => error("invalid @option: $ex")
    end
end

"""
    split_body(ex::Expr) -> fields::Vector{Field}, misc::Vector{Any}

Split the fields of option type declaration and misc (such as inner constructors etc.).
"""
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

            Expr(:(=), name::Symbol, default) => Field(name, Any, default, line)

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

function name_only(@nospecialize(ex))
    ex isa Expr || return ex
    ex.head === :call && return name_only(ex.args[1])
    ex.head === :curly && return name_only(ex.args[1])
    ex.head === :(<:) && return name_only(ex.args[1])
    error("unsupported expression $ex")
end

function has_symbol(@nospecialize(ex), name::Symbol)
    ex isa Symbol && return ex === name
    ex isa Expr || return false
    return any(x->has_symbol(x, name), ex.args)
end

function default_depends_on_typevars(def::OptionDef)
    typevars = map(name_only, def.parameters)
    for each in def.fields, tvar in typevars
        if has_symbol(each.default, tvar)
            return true
        end
    end
    return false
end

function field_has_typevars(def::OptionDef)
    typevars = map(name_only, def.parameters)
    for each in def.fields, tvar in typevars
        if has_symbol(each.type, tvar)
            return true
        end
    end
    return false
end

function typevars_can_be_inferred(def::OptionDef)
    field_has_typevars(def) && !default_depends_on_typevars(def)
end

function get_kw_expr(def::OptionDef)
    kwargs = []
    for each in def.fields
        if each.default === no_default
            push!(kwargs, each.name)
        else
            push!(kwargs, Expr(:kw, each.name, each.default))
        end
    end
    return kwargs
end

function codegen_kw_fn(x::OptionDef)
    isempty(x.fields) && return
    has_custom_kw_fn(x) && return
    kwargs = get_kw_expr(x)

    def = Dict(
            :name => x.name,
            :kwargs => kwargs,
            :body => Expr(:call, x.name, [each.name for each in x.fields]...)
        )

    if isempty(x.parameters)
        return combinedef(def)
    else
        typevars = map(name_only, x.parameters)
        T = Expr(:curly, x.name, typevars...)
        curly_def = Dict(
            :name => T,
            :kwargs => kwargs,
            :body => Expr(:call, T, [each.name for each in x.fields]...),
            :whereparams => x.parameters,
        )

        if typevars_can_be_inferred(x)
            return quote
                $(combinedef(def))
                $(combinedef(curly_def))
            end
        else
            return combinedef(curly_def)
        end
    end
end

option_print(io::IO, m::MIME, x) = show(io, m, x)
option_print(io::IO, ::MIME, x::AbstractDict) = show(io, x)

function option_print(io::IO, m::MIME"text/plain", x::AbstractDict{String})
    head_indent = get(io, :head_indent, 0)
    indent = get(io, :indent, 0)
    println(io, " "^head_indent, typeof(x), "(")
    for (k, v) in x
        print(io, " "^(indent+4), LIGHT_BLUE_FG("\"", k, "\""), " => ")
        option_print(IOContext(io, :indent=>(indent+4)), m, v)
        println(io, ",")
    end
    print(io, " "^indent, ")")
end

# inline printing arrays
option_print(io::IO, ::MIME, x::AbstractArray) = show(io, x)

function option_print(io::IO, m::MIME, list::Vector)
    if !(any(is_option, list) || length(list) > 4)
        return show(io, list)
    end

    head_indent = get(io, :head_indent, 0)
    indent = get(io, :indent, 0)
    println(io, " "^head_indent, "[")
    inner_io = IOContext(io, :indent=>indent+4, :head_indent=>indent+4)
    for each in list
        if is_option(each)
            show(inner_io, m, each)
        else # inline
            show(inner_io, each)
        end

        if length(list) > 1
            println(io, ", ")
        end
    end
    print(io, " "^(indent), "]")
end

function codegen_show_text(x::OptionDef)
    body = quote
        head_indent = get(io, :head_indent, 0)
        indent = get(io, :indent, 0)
        println(io, " "^head_indent, $GREEN_FG(summary(x)), "(;")
    end

    for each in x.fields
        print_ex = quote
            print(io, " "^(indent+4), $(LIGHT_BLUE_FG(string(each.name))), " = ")
            $(GlobalRef(Configurations, :option_print))(IOContext(io, :indent=>(indent+4)), m, x.$(each.name))
            println(io, ",")
        end

        if each.default !== no_default
            push!(body.args, quote
                if x.$(each.name) != field_default(typeof(x), $(QuoteNode(each.name)))
                    $print_ex
                end
            end)
        else
            push!(body.args, print_ex)
        end
    end

    push!(body.args, :(print(io, " "^indent, ")")))

    if isempty(x.parameters)
        T = x.name
        def = Dict(
            :name => GlobalRef(Base, :show),
            :args => [:(io::IO), :(m::MIME"text/plain"), :(x::$T)],
            :body => body,
        )
    else
        T = Expr(:curly, x.name, map(name_only, x.parameters)...)
        def = Dict(
            :name => GlobalRef(Base, :show),
            :args => [:(io::IO), :(m::MIME"text/plain"), :(x::$T)],
            :body => body,
            :whereparams => x.parameters,
        )
    end

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

replace_symbol(x::Symbol, name::Symbol, value) = x === name ? value : x
replace_symbol(x, ::Symbol, value) = x # other expressions

function replace_symbol(ex::Expr, name::Symbol, value)
    Expr(ex.head, map(x->replace_symbol(x, name, value), ex.args)...)
end

function resolve_defaults(x::OptionDef)
    map = Dict{Symbol, Any}()
    for each in x.fields
        default = each.default
        for prev in keys(map)
            if has_symbol(each.default, prev)
                default = replace_symbol(each.default, prev, map[prev])
            end
        end
        map[each.name] = default
    end
    return map
end

function codegen_field_default(x::OptionDef)
    dmap = resolve_defaults(x)
    obj = gensym(:x)
    msg = Expr(:string, "type $(x.name) does not have field ", obj)
    err = :(error($msg))
    body = isempty(x.fields) ? err : Expr(:if)
    stmt = body

    for k in 1:length(x.fields)
        field = x.fields[k]
        push!(stmt.args, :($obj == $(QuoteNode(field.name))))
        push!(stmt.args, dmap[field.name])

        if k != length(x.fields)
            push!(stmt.args, Expr(:elseif))
            stmt = stmt.args[end]
        else
            push!(stmt.args, err)
        end
    end

    if isempty(x.parameters)
        def = Dict(
            :name => GlobalRef(Configurations, :field_default),
            :args => [:(::Type{$(x.name)}), :($obj::Symbol)],
            :body => body
        )
    else
        T = Expr(:curly, x.name, map(name_only, x.parameters)...)
        def = Dict(
            :name => GlobalRef(Configurations, :field_default),
            :args => [:(::Type{$T}), :($obj::Symbol)],
            :body => body,
            :whereparams => x.parameters,
        )
    end

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

"""
    create(::Type{T}; kwargs...) where T
    
Create an instance of option type `T` from `kwargs`. Similar
to the default keyword argument constructor, but one can use this to create
custom keyword argument constructor with extra custom keywords.
"""
function create(::Type{T}; kwargs...) where T
    error("$T is not an option type")
end

function codegen_create(x::OptionDef)
    def = Dict(
        :name => GlobalRef(Configurations, :create),
        :args => [:(::Type{T})],
        :kwargs => get_kw_expr(x),
        :whereparams => [:(T <: $(x.name))],
        :body => Expr(:call, :T, [each.name for each in x.fields]...)
    )
    return combinedef(def)
end

"""
    compare_options(a, b, xs...)::Bool

Compare option types check if they are the same.
"""
function compare_options(a, b, xs...)::Bool
    compare_options(a, b) || return false
    compare_options(b, xs...)
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

function codegen_show_toml_mime(x::OptionDef)
    :(
        function Base.show(io::IO, ::MIME"application/toml", x::$(x.name))
            return print(io, to_toml(x))
        end
    )
end

"""
generate Julia AST from `OptionDef`.
"""
function codegen(def::OptionDef)
    quote
        $(codegen_struct_def(def))
        Core.@__doc__ $(def.name)
        $(codegen_kw_fn(def))
        $(codegen_convert(def))
        $(codegen_show_text(def))
        $(codegen_is_option(def))
        $(codegen_field_default(def))
        $(codegen_alias(def))
        $(codegen_isequal(def))
        $(codegen_show_toml_mime(def))
        $(codegen_create(def))
    end
end

function option_m(@nospecialize(ex), alias=nothing)
    def = OptionDef(ex, alias)

    quote
        $(codegen(def))
        nothing
    end
end

"""
    @option [alias::String] <struct def>

Define an option struct type. This will auto-generate methods that parse a given `Dict{String}`
object (the keys must be of type `String`) into an instance of the struct type you defined. One
can use `alias` string to distinguish multiple possible option type for the same field.

# Example

One can define option type via `@option` macro with or without an alias.

```julia-repl
julia> "Option A"
       @option "option_a" struct OptionA
           name::String
           int::Int = 1
       end

julia> "Option B"
       @option "option_b" struct OptionB
           opt::OptionA = OptionA(;name = "Sam")
           float::Float64 = 0.3
       end
```

and convert a dict to an option type via [`from_dict`](@ref).

```julia-repl
julia> d = Dict{String, Any}(
           "opt" => Dict{String, Any}(
               "name" => "Roger",
               "int" => 2,
           ),
           "float" => 0.33
       );

julia> option = from_dict(OptionB, d)
OptionB(;
    opt = OptionA(;
        name = "Roger",
        int = 2,
    ),
    float = 0.33,
)
```

when there are multiple possible option type for one field,
one can use the alias to distinguish them

```julia-repl
julia> @option struct OptionD
           opt::Union{OptionA, OptionB}
       end

julia> d1 = Dict{String, Any}(
               "opt" => Dict{String, Any}(
                   "option_b" => d
               )
           );

julia> from_dict(OptionD, d1)
OptionD(;
    opt = OptionB(;
        opt = OptionA(;
            name = "Roger",
            int = 2,
        ),
        float = 0.33,
    ),
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

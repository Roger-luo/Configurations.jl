module Configurations

export @option, from_dict, from_kwargs, from_toml, to_dict, to_toml

using OrderedCollections
using MatchCore
using Crayons.Box
using ExprTools
using TOML

"""
    option_convert(::Type{OptionType}, ::Type{ValueType}, x) where {OptionType, ValueType}

Convert `x` to type `ValueType` for option type `OptionType`. This is similar to `Base.convert`,
when creating an instance of the option type, but one can use this to avoid type piracy.
"""
option_convert(::Type, ::Type{A}, x) where {A} = nothing

option_convert(::Type, ::Type{VersionNumber}, x::String) = VersionNumber(x)

function option_convert_union(::Type{T}, ::Type{A}, x) where {T, A}
    if !(A isa Union)
        v = option_convert(T, A, x)
        v === nothing || return v
        return
    end

    v = option_convert_union(T, A.a, x)
    v === nothing || return v
    return option_convert_union(T, A.b, x)
end

"""
    toml_convert(::Type, x)

A convenient function for converting common Julia types to TOML compatible types. One
can overload the first argument to custom the behaviour for a specific option type.
"""
toml_convert(::Type, x) = x
toml_convert(::Type, x::VersionNumber) = string(x)

"""
    toml_convert(::Type{T}) where T

Curried version of `toml_convert`.
"""
toml_convert(::Type{T}) where T = x->toml_convert(T, x)

"""
    to_toml(x; sorted=false, by=identity, include_defaults=false)

Convert an instance `x` of option type to TOML and write it to `String`. See also `TOML.print`. 

`to_toml` does not export fields that are of the same values as the defaults. This can be 
overridden by changing `include_defaults` to `true`.
"""
function to_toml(x; sorted=false, by=identity, include_defaults=false)
    return sprint(x) do io, x
        to_toml(io, x; sorted=sorted, by=by, include_defaults=include_defaults)
    end
end

function to_toml(io::IO, x; sorted=false, by=identity, include_defaults=false)
    return to_toml(toml_convert(typeof(x)), io, x; sorted=sorted, by=by, include_defaults=include_defaults)
end

function to_toml(filename::String, x; sorted=false, by=identity, include_defaults=false)
    return to_toml(toml_convert(typeof(x)), filename, x; sorted=sorted, by=by, include_defaults=include_defaults)
end

"""
    to_toml([f::Function], filename::String, option; sorted=false, by=identity, include_defaults=false)

Convert an instance `option` of option type to TOML and write it to `filename`. See also `TOML.print`.
"""
function to_toml(f, filename::String, x; sorted=false, by=identity, include_defaults=false)
    open(filename, "w+") do io
        to_toml(f, io, x; sorted=sorted, by=by, include_defaults=include_defaults)
    end
end

"""
    to_toml([f::Function], io::IO, option; sorted=false, by=identity, include_defaults=false)

Convert an instance `option` of option type to TOML and write it to `IO`. See also `TOML.print`.
"""
function to_toml(f, io::IO, x; sorted=false, by=identity, include_defaults=false)
    return TOML.print(f, io, to_dict(x; include_defaults=include_defaults); sorted=sorted, by=by)
end

@deprecate toml to_toml



# we don't process other kind of value

"""
    codegen_show_text(x::OptionDef)

Generate `Base.show` overloading for given type for the default
printing syntax.
"""
function codegen_show_text(x::OptionDef)
    body = quote
        head_indent = get(io, :head_indent, 0)
        indent = get(io, :indent, 0)
        all_default = true
        print(io, " "^head_indent, $GREEN_FG(summary(x)), "(")
    end

    is_first_field = true
    for each in x.fields
        print_ex = quote
            all_default = false
            print(io, " "^(indent+4), $(LIGHT_BLUE_FG(string(each.name))), " = ")
            $(GlobalRef(Configurations, :option_print))(IOContext(io, :indent=>(indent+4)), m, x.$(each.name))
            println(io, ",")
        end

        if is_first_field
            pushfirst!(print_ex.args, :(println(io, ";")))
            is_first_field = false
        end

        if each.default !== no_default
            push!(body.args, quote
                default = $field_default(typeof(x), $(QuoteNode(each.name)))
                if default isa $PartialDefault
                    default = default(x)
                end

                if x.$(each.name) != default
                    $print_ex
                end
            end)
        else
            push!(body.args, print_ex)
        end
    end

    push!(body.args, :(all_default || print(io, " "^indent)))
    push!(body.args, :(print(io, ")")))

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

"""
    codegen_field_alias(x::OptionDef)

Generate the field alias method [`field_alias`](@ref).
"""
function codegen_field_alias(x::OptionDef)
    obj = gensym(:x)
    msg = Expr(:string, "type $(x.name) does not have field ", obj)
    err = :(error($msg))
    body = isempty(x.fields) ? err : Expr(:if)
    stmt = body

    for k in 1:length(x.fields)
        field = x.fields[k]
        push!(stmt.args, :($obj == $(QuoteNode(field.name))))
        push!(stmt.args, field.alias)

        if k != length(x.fields)
            push!(stmt.args, Expr(:elseif))
            stmt = stmt.args[end]
        else
            push!(stmt.args, err)
        end
    end

    if isempty(x.parameters)
        def = Dict(
            :name => GlobalRef(Configurations, :field_alias),
            :args => [:(::Type{$(x.name)}), :($obj::Symbol)],
            :body => body
        )
    else
        X = gensym(:T)
        def = Dict(
            :name => GlobalRef(Configurations, :field_alias),
            :args => [:(::Type{$X}), :($obj::Symbol)],
            :body => body,
            :whereparams => [x.parameters..., :($X <: $(x.name){$(name_only.(x.parameters)...)})],
        )
    end
    return combinedef(def)
end


end

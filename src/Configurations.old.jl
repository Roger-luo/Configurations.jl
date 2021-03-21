module Configurations

export @option, from_dict, from_kwargs, from_toml, to_dict, to_toml

using OrderedCollections
using MatchCore
using Crayons.Box
using ExprTools
using TOML


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

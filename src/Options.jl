module Options

using MatchCore
using ExprTools

export @option

isoption(x) = false

macro option(expr)
    expr = macroexpand(__module__, expr)
    return esc(option_m(expr))
end

option_m(x) = error("invalid usage of @option")

function option_m(ex::Expr)
    ex.head === :struct || error("invalid usage of @option")
    ex.args[1] && error("options must be immutable")
    T = ex.args[2]
    body = ex.args[3]::Expr

    args, kwdefs, body = split_kwdef(body)
    struct_def = quote
        Core.@__doc__ $(Expr(:struct, ex.args[1], T, body))
    end
    isempty(kwdefs) && return struct_def

    if T isa Expr && T.head === :(<:) # supertype
        T = T.args[1]
    end
    ex = Expr(:block, struct_def)

    # contain typevars
    if T isa Expr && T.head === :curly
        S = T.args[1]
        P = T.args[2:end]
        Q = Any[U isa Expr && U.head === :(<:) ? U.args[1] : U for U in P]
        SQ = :($S{$(Q...)})

        push!(ex.args, quote
            function $SQ(;$(kwdefs...)) where {$(P...)}
                $SQ($(args...))
            end
        end)
    end

    push!(ex.args, quote
        function $(object_name(T))(;$(kwdefs...))
            $(object_name(T))($(args...))
        end
    end)

    # printing
    print_stmts = Expr(:block)
    for each in args
        push!(print_stmts.args, quote
            print(inner_io, " "^indent, " "^2, $(string(each)), " = ")
            show(inner_io, x.$each)
            println(inner_io, ", ")
        end)
    end

    push!(ex.args, quote
        function Base.show(io::IO, x::$(object_name(T)))
            indent = get(io, :indent, 0)
            summary(io, x)
            println(io, "(")
            inner_io = IOContext(io, :indent => indent + 2)
            $(print_stmts)
            print(io, " "^indent, ")")
        end
    end)

    push!(ex.args, :( $(GlobalRef(Options, :isoption))(::Type{<:$(object_name(T))}) = true))
    push!(ex.args, :( $(GlobalRef(Options, :isoption))(::$(object_name(T))) = true ))
    
    push!(ex.args, nothing)
    return ex
end

function split_kwdef(ex::Expr)
    ex.head === :block || error("expect a block")
    args = Symbol[]
    kwdefs = []
    body = Expr(:block)
    for each in ex.args
        if each isa Expr
            if each.head === :(=)
                push!(body.args, each.args[1])
                name = object_name(each)
                push!(args, name)
                push!(kwdefs, Expr(:kw, name, each.args[2]))
            else
                push!(body.args, each)
                name = object_name(each)
                push!(args, name)
                push!(kwdefs, name)
            end
        else
            push!(body.args, each)
        end
    end
    return args, kwdefs, body
end

function object_name(ex)
    ex isa Expr || return ex

    if ex.head === :struct
        return object_name(ex.args[1])
    elseif ex.head === :(<:)
        return object_name(ex.args[1])
    elseif ex.head === :curly
        return object_name(ex.args[1])
    elseif ex.head === :(=)
        return object_name(ex.args[1])
    elseif ex.head === :(::)
        return object_name(ex.args[1])
    else
        error("unrecognized expression: $ex")
    end
end

function from_dict(::Type{T}, d::AbstractDict) where T
    isoption(T) || error("type $T is not an option type")
    kwargs = []
    for (k, v) in d
        for each in fieldnames(T)
            if k == string(each)
                push!(kwargs, each=>v)
            end
        end
    end
    return T(;kwargs...)
end

end

module Configurations

export @option

using OrderedCollections
using MatchCore
using Crayons.Box
using ExprTools
using TOML

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

dictionalize(x) = x
is_option(x) = false


struct NoDefault end

const no_default = NoDefault()
const Maybe{T} = Union{Nothing, T}

struct Field
    name::Symbol
    type::Any
    default::Any
    line
end

struct OptionDef
    name::Symbol
    ismutable::Bool
    parameters::Vector{Any}
    supertype

    fields::Vector{Field}
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

function OptionDef(@nospecialize(ex))
    ex isa Expr || error("invalid usage of @option")
    ex.head === :struct || error("invalid usage of @option")

    name, parameters, supertype = split_name(ex)
    fields = split_body(ex)
    return OptionDef(name, ex.args[1], parameters, supertype, fields)
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
            _ => error("invalid @option statement: $each")
        end

        if item isa Field
            push!(fields, item)
        end
    end
    return fields
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

function codegen_from_dict(x::OptionDef)
    d = gensym(:d)
    validate = Expr(:block)
    create = Expr(:call, x.name)
    # check required fields
    for each in x.fields
        key = string(each.name)
        msg = "option $key is required"
        if each.default === no_default
            push!(validate.args, :($haskey($d, $key) || $error($msg)))
            push!(create.args, :($d[$key]))
        else
            push!(create.args, :($get($d, $key, $(each.default))))
        end
    end

    def = Dict(
        :name => x.name,
        :args => [:($d::AbstractDict{String})],
        :body => quote
            $validate
            $create
        end
    )

    return combinedef(def)
end

function codegen_from_toml(x::OptionDef)
    return :(
        function $(x.name)(filename::String)
            $(x.name)($TOML.parsefile(filename))
        end
    )
end

function codegen_show_text(x::OptionDef)
    body = quote
        indent = get(io, :indent, 0)
        println(io, $(GREEN_FG(string(x.name))), "(;")
    end

    for each in x.fields
        push!(body.args, :( print(io, " "^(indent+4), $(LIGHT_BLUE_FG(string(each.name))), " = ") ))
        push!(body.args, :( show(IOContext(io, :indent=>(indent+4)), m, x.$(each.name)) ))
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

function codegen_to_dict(x::OptionDef)
    dict = Expr(:call, :($OrderedDict{String, Any}))

    for each in x.fields
        key = string(each.name)
        push!(dict.args, :($key => $dictionalize(option.$(each.name))))
    end

    def = Dict(
        :name => GlobalRef(Configurations, :dictionalize),
        :args => [:(option::$(x.name))],
        :body => quote
            return $dict
        end,
    )
    return combinedef(def)
end

function codegen_is_option(x::OptionDef)
    :($(GlobalRef(Configurations, :is_option))(::$(x.name)) = true)
end

function codegen_convert(x::OptionDef)
    :(Base.convert(::Type{<:$(x.name)}, d::AbstractDict{String}) = $(x.name)(d))
end

function option_m(@nospecialize(ex))
    def = OptionDef(ex)

    quote
        $(codegen_struct_def(def))
        Core.@__doc__ $(def.name)
        $(codegen_kw_fn(def))
        $(codegen_from_dict(def))
        $(codegen_from_toml(def))
        $(codegen_convert(def))
        $(codegen_to_dict(def))
        $(codegen_show_text(def))
        $(codegen_is_option(def))
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

end

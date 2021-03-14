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

function option_m(ex, type_alias=nothing)
    def = JLKwStruct(ex, type_alias)
    quote
        $(codegen_ast(def))
        Core.@__doc__ $(def.name)
        $(codegen_create(def))
        $(codegen_is_option(def))
        $(codegen_convert(def))
        $(codegen_field_default(def))
        $(codegen_field_alias(def))
        $(codegen_type_alias(def))
        $(codegen_isequal(def))
        # pretty printings
        $(codegen_show(def))
        nothing
    end
end

"""
    codegen_is_option(x::JLKwStruct)

Generate the [`is_option`](@ref) method.
"""
function codegen_is_option(def::JLKwStruct)
    quote
        $Configurations.is_option(::$(def.name)) = true
        $Configurations.is_option(::Type{<:$(def.name)}) = true
    end
end

"""
    codegen_convert(x::JLKwStruct)

Generate `Base.convert` from `AbstractDict{String}` to the given option type.
"""
function codegen_convert(def::JLKwStruct)
    quote
        $Base.convert(::Type{<:$(def.name)}, d::AbstractDict{String}) =
            $Configurations.from_dict($(def.name), d)
    end
end

function codegen_field_default(def::JLKwStruct)
    obj = gensym(:x)
    msg = Expr(:string, "type $(def.name) does not have field ", obj)
    err = :(error($msg))
    ret = JLIfElse()
    ret.otherwise = err

    isconst = Dict{Symbol, Bool}()
    default = Dict{Symbol, Any}()
    prev_field_names = Symbol[]
    obj = gensym(:x)

    for (k, field) in enumerate(def.fields)
        vars = Symbol[]

        for name in prev_field_names
            if has_symbol(field.default, name)
                push!(vars, name)
            end
        end

        cond = :($obj == $(QuoteNode(field.name)))

        if isempty(vars) # const default
            ret.map[cond] = field.default
        else
            jlfn = JLFunction(;
                args=vars,
                body=field.default,
            )
            fn = gensym(:fn)
            ret.map[cond] = quote
                $fn = $(codegen_ast(jlfn))
                $PartialDefault($fn, $vars, $(Expr(:quote, field.default)))
            end
        end

        push!(prev_field_names, field.name)
    end

    return codegen_ast(
        JLFunction(;
            name=GlobalRef(Configurations, :field_default),
            args=[:(::Type{<:$(def.name)}), :($obj::Symbol)],
            body=codegen_ast(ret)
        )
    )
end

function codegen_field_alias(def::JLKwStruct)
end

"""
    codegen_isequal(x::JLKwStruct)

Generate `Base.:(==)` to overload comparison operator to [`compare_options`](@ref)
for given option type.
"""
function codegen_isequal(x::JLKwStruct)
    return :(Base.:(==)(a::$(x.name), b::$(x.name)) = $compare_options(a, b))
end

"""
    codegen_type_alias(def::JLKwStruct)

Generate type alias method [`type_alias`](@ref).
"""
function codegen_type_alias(def::JLKwStruct)
    quote
        $Configurations.type_alias(::Type{<:$(def.name)}) = $(def.typealias)
    end
end

function codegen_create(def::JLKwStruct)
    codegen_ast_kwfn(def, GlobalRef(Configurations, :create))
end

function codegen_show(def::JLKwStruct)
    quote
        function $Base.show(io::IO, m::MIME"text/plain", x::$(def.name))
            $show_option(io, m, x)
        end

        function $Base.show(io::IO, m::MIME"text/html", x::$(def.name))
            $show_option(io, m, x)
        end

        function $Base.show(io::IO, ::MIME"application/toml", x::$(def.name))
            return print(io, to_toml(x))
        end
    end
end

"""
    @option [alias::String] <struct def>

Define an option struct type. This will auto-generate methods that parse a given `Dict{String}`
object (the keys must be of type `String`) into an instance of the struct type you defined. One
can use `alias` string to distinguish multiple possible option type for the same field.

!!! compat "Configurations 0.16"
    from v0.16.0 Configurations stops overloading the `Base.show` method for you,
    if you need pretty printing of your option types, consider overloading
    the `Base.show(io::IO, mime::MIME, x)` method to `pprint_struct(io, mime, x)` provided by
    [GarishPrint](https://github.com/Roger-luo/GarishPrint.jl)

!!! compat "Configurations 0.12"
    from v0.12.0 the field alias feature is removed due to the syntax conflict with
    field docstring. Please refer to [#17](https://github.com/Roger-luo/Configurations.jl/issues/17).

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
    esc(option_m(__module__, ex))
end

macro option(alias::String, ex)
    esc(option_m(__module__, ex, alias))
end

function option_m(mod::Module, ex, type_alias=nothing)
    ex = macroexpand(mod, ex)
    def = JLKwStruct(ex, type_alias)
    has_duplicated_reflect_type(mod, def) && throw(
        ArgumentError("struct fields contain duplicated `Reflect` type")
    )
    add_field_defaults!(mod, def)
    return codegen_option_type(def)
end

"""
    codegen_option_type(def::JLKwStruct)

Generate the `Configurations` option type definition from
a given `JLKwStruct` created by [`Expronicon`](https://github.com/Roger-luo/Expronicon.jl).
"""
function codegen_option_type(def::JLKwStruct)
    quote
        $(codegen_ast(def))
        Core.@__doc__ $(def.name)
        $(codegen_create(def))
        $(codegen_is_option(def))
        $(codegen_convert(def))
        $(codegen_field_default(def))
        $(codegen_type_alias(def))
        $(codegen_isequal(def))
        nothing
    end
end

function add_field_defaults!(m::Module, def::JLKwStruct)
    for field in def.fields
        if is_reflect_type_expr(m, field.type)
            field.default = Reflect()
        elseif is_maybe_type_expr(m, field.type) && field.default === no_default
            field.default = nothing
        end
    end
    return def
end

function has_duplicated_reflect_type(m::Module, def::JLKwStruct)
    has_reflect_type = false
    for field in def.fields
        if is_reflect_type_expr(m, field.type)
            has_reflect_type && return true
            has_reflect_type = true
        end
    end
    return false
end

function is_reflect_type_expr(m::Module, @nospecialize(ex))
    if isdefined(m, :Reflect) && (eval(GlobalRef(m, :Reflect)) === Reflect)
        ex === :Reflect && return true
    end
    # no need to check definition
    ex == Reflect && return true
    ex == GlobalRef(Configurations, :Reflect) && return true
    ex == :($Configurations.Reflect) && return true
    ex == :($Configurations.$Reflect) && return true
    ex == :(Configurations.$Reflect) && return true
    if isdefined(m, :Configurations)
        ex == :(Configurations.Reflect) && return true
    end
    return false
end

function is_maybe_type_expr(m::Module, @nospecialize(ex))
    if isdefined(m, :Maybe) && (eval(GlobalRef(m, :Maybe)) === Maybe)
        _is_maybe_type_expr(ex) && return true
    end

    if ex isa GlobalRef && ex.mod === Configurations
        ex.name === :Maybe && return true
    end

    if ex isa Type && ex isa Union && Nothing <: ex
        return true
    end

    ex isa Expr || return false
    if ex.head === :.
        if ex.args[1] === Configurations || ex.args[1] === :Configurations
            return _is_maybe_type_expr(ex.args[2])
        end
    elseif ex.head === :curly
        return is_maybe_type_expr(m, ex.args[1])
    end
    return false
end

function _is_maybe_type_expr(@nospecialize(ex))
    ex === Maybe && return true
    ex === :Maybe && return true
    if ex isa QuoteNode
        ex.value === :Maybe && return true
        ex.value isa Type && ex.value <: Maybe && return true
    end

    ex isa Expr || return false
    if ex.head === :curly
        ex.args[1] === :Maybe && return true
        ex.args[1] isa Type && ex.args[1] <: Maybe && return true
    end
    return false
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
        function $Base.convert(::Type{<:$(def.name)}, d::AbstractDict{String})
            $Configurations.from_dict($(def.name), d)
        end
    end
end

"""
    codegen_field_default(def::JLKwStruct)

Generate [`field_default`](@ref) overload to support the default value
reflection.
"""
function codegen_field_default(def::JLKwStruct)
    obj = gensym(:x)
    msg = Expr(:string, "type $(def.name) does not have field ", obj)
    err = :(error($msg))
    ret = JLIfElse()
    ret.otherwise = err

    isconst = Dict{Symbol, Bool}()
    default = Dict{Symbol, Any}()
    prev_field_names = Symbol[]

    for (k, field) in enumerate(def.fields)
        vars = Symbol[]

        for name in prev_field_names
            if has_symbol(field.default, name)
                push!(vars, name)
            end
        end

        cond = :($obj == $(QuoteNode(field.name)))

        if isempty(vars) # const default
            ret[cond] = field.default
        else
            jlfn = JLFunction(;
                args=vars,
                body=field.default,
            )
            fn = gensym(:fn)
            ret[cond] = quote
                $fn = $(codegen_ast(jlfn))
                $PartialDefault($fn, $vars, $(Expr(:quote, field.default)))
            end
        end

        push!(prev_field_names, field.name)
    end

    type = gensym(:type)
    typevars = name_only.(def.typevars)
    ub = isempty(def.typevars) ? def.name : Expr(:curly, def.name, typevars...)

    return codegen_ast(
        JLFunction(;
            name=:($Configurations.field_default),
            args=[:(::Type{$type}), :($obj::Symbol)],
            body=codegen_ast(ret),
            whereparams=[typevars..., :($type <: $ub)],
        )
    )
end

# function codegen_field_alias(def::JLKwStruct)
# end

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

"""
    codegen_create(def::JLKwStruct)

Generate [`Configurations.create`](@ref) overload.
"""
function codegen_create(def::JLKwStruct)
    codegen_ast_kwfn(def, :($Configurations.create))
end

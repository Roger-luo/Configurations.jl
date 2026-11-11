module TestIssues

using Test
using Configurations

# #101: field names must not clash with the generated `from_dict_specialize` arguments
@option struct Issue101
    d::Union{Nothing, String} = nothing
    e::String
end

@option struct Issue101StaticParam
    T::Int = 1
    value::Int = 2
end

@testset "#101 field names clash with generated code" begin
    @test from_dict(Issue101, Dict("d" => nothing, "e" => "hi")) == Issue101(nothing, "hi")
    @test from_dict(Issue101, Dict("d" => "x", "e" => "hi")) == Issue101("x", "hi")
    @test from_dict(Issue101StaticParam, Dict("T" => 5)) == Issue101StaticParam(5, 2)
end

# #103: use another field directly as the default value
@option struct Issue103
    a = 3
    b = a
end

@testset "#103 another field as default" begin
    @test Issue103() == Issue103(3, 3)
    @test Issue103(; a = 5) == Issue103(5, 5)
    @test from_dict(Issue103, Dict{String, Any}("a" => 5)) == Issue103(5, 5)
    @test from_dict(Issue103, Dict{String, Any}("a" => 5, "b" => 1)) == Issue103(5, 1)
end

# #97: user overloaded conversion from a non-vector to a vector field
@option struct Issue97
    xs::Vector{Float64}
end

Configurations.from_dict(::Type{Issue97}, ::Type{Vector{Float64}}, s::AbstractString) =
    s == "+X" ? [1.0, 0.0, 0.0] : error("unknown axis $s")

@testset "#97 custom conversion to vector" begin
    @test from_dict(Issue97, Dict("xs" => "+X")) == Issue97([1.0, 0.0, 0.0])
    @test from_dict(Issue97, Dict("xs" => [1, 2])) == Issue97([1.0, 2.0])
end

# #96: vector of union of option types with `Reflect` field
@option "issue96_a" struct Issue96A
    type::Reflect
    a::Int
end

@option "issue96_b" struct Issue96B
    type::Reflect
    b::Int
end

@option struct Issue96
    vec::Vector{Union{Issue96A, Issue96B}}
end

@option "issue96_c" struct Issue96C
    c::Int = 1
end

@option struct Issue96Mixed
    vec::Vector{Union{Int, Issue96C}}
end

@testset "#96 vector of union" begin
    x = Issue96([Issue96A(Reflect(), 1), Issue96B(Reflect(), 2)])
    @test from_dict(Issue96, to_dict(x)) == x
    file = tempname() * ".toml"
    to_toml(file, x)
    @test from_toml(Issue96, file) == x

    y = Issue96Mixed([1, Issue96C(2)])
    @test from_dict(Issue96Mixed, to_dict(y)) == y
end

# #17: field docstrings
"Issue17 docstring"
@option "issue17" struct Issue17
    "doc of x"
    x::Int
    "doc of y"
    y::Real = 1
end

@option struct Issue17NoDoc
    a::Int = 1
end

@testset "#17 field docstrings" begin
    binding = Base.Docs.Binding(@__MODULE__, :Issue17)
    docstr = Base.Docs.meta(@__MODULE__)[binding].docs[Union{}]
    @test docstr.data[:fields][:x] == "doc of x"
    @test docstr.data[:fields][:y] == "doc of y"
    @test occursin("Issue17 docstring", string(@doc(Issue17)))
    @test Issue17(; x = 2) == Issue17(2, 1)
    @test from_dict(Issue17, Dict{String, Any}("x" => 3)) == Issue17(3, 1)
    @test Issue17NoDoc() == Issue17NoDoc(1)
end

# #105: specify a whole option value in keyword arguments
@option struct Issue105Inner
    name::String = "a"
    int::Int = 1
end

@option struct Issue105
    opt::Issue105Inner = Issue105Inner()
    float::Float64 = 0.1
    maybe::Maybe{Issue105Inner} = nothing
end

@option struct Issue105Outer
    sub::Issue105 = Issue105()
end

# unambiguous in the field convention (no duplicated sub-field names)
@option struct Issue105Field
    opt::Issue105Inner = Issue105Inner()
    float::Float64 = 0.1
end

@option struct Issue105FieldOuter
    sub::Issue105Field = Issue105Field()
end

# ambiguous types in the field convention
@option struct Issue105DupOption
    name::Issue105Inner = Issue105Inner() # sub-field `name` clashes with the field
end

@option struct Issue105UnionInner
    m::Maybe{Int} = nothing
end

@option struct Issue105DupUnion
    sub::Issue105UnionInner = Issue105UnionInner()
    m::Maybe{Int} = nothing
end

@testset "#105 whole option value in kwargs" begin
    inner = Issue105Inner("x", 2)
    @test from_kwargs(Issue105; opt = inner) == Issue105(; opt = inner)
    @test from_kwargs(Issue105; opt = Dict("name" => "y")) == Issue105(; opt = Issue105Inner(; name = "y"))
    @test from_kwargs(Issue105; maybe = inner, float = 0.5) == Issue105(; maybe = inner, float = 0.5)
    # leaf keywords still work
    @test from_kwargs(Issue105; opt_name = "z") == Issue105(; opt = Issue105Inner(; name = "z"))

    # nested: whole value at any level
    @test from_kwargs(Issue105Outer; sub_opt = inner) == Issue105Outer(; sub = Issue105(; opt = inner))
    @test from_kwargs(Issue105Outer; sub = Issue105(; float = 2.0)) == Issue105Outer(; sub = Issue105(; float = 2.0))

    # overriding a parsed dict
    d = Dict{String,Any}("opt" => Dict{String,Any}("name" => "d"), "float" => 1.0)
    @test from_dict(Issue105, d; opt = inner) == Issue105(; opt = inner, float = 1.0)

    # field convention
    @test Configurations.from_field_kwargs(Issue105FieldOuter; opt = inner) ==
        Issue105FieldOuter(; sub = Issue105Field(; opt = inner))
    @test Configurations.from_field_kwargs(Issue105FieldOuter; sub = Issue105Field(; float = 3.0)) ==
        Issue105FieldOuter(; sub = Issue105Field(; float = 3.0))
    @test Configurations.from_field_kwargs(Issue105FieldOuter; name = "n") ==
        Issue105FieldOuter(; sub = Issue105Field(; opt = Issue105Inner(; name = "n")))

    # whole value and sub-field keywords together are ambiguous
    @test_throws ArgumentError from_kwargs(Issue105; opt = inner, opt_name = "z")
    @test_throws ArgumentError from_kwargs(Issue105; maybe = inner, maybe_int = 3)
    @test_throws ArgumentError from_kwargs(Issue105Outer; sub = Issue105(), sub_opt_name = "z")
    @test_throws ArgumentError Configurations.from_field_kwargs(Issue105FieldOuter; opt = inner, name = "z")

    @test_throws DuplicatedFieldError Configurations.from_field_kwargs(Issue105DupOption; int = 1)
    @test_throws DuplicatedFieldError Configurations.from_field_kwargs(Issue105DupUnion; m = 1)

    # still rejects unknown keywords
    @test_throws InvalidKeyError from_kwargs(Issue105; foo = 1)
end

end # module

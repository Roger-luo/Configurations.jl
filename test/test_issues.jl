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

end # module

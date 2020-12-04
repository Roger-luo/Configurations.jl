using Configurations
using Configurations: to_dict, to_toml, from_kwargs, from_dict,
    from_toml, no_default, field_defaults, field_default
using OrderedCollections
using Test

"Option A"
@option "option_a" struct OptionA
    name::String
    int::Int = 1
end

"Option B"
@option "option_b" struct OptionB
    opt::OptionA = OptionA(;name = "Sam")
    float::Float64 = 0.3
end

d = OrderedDict{String, Any}(
    "opt" => OrderedDict{String, Any}(
        "name" => "Roger",
        "int" => 2,
    ),
    "float" => 0.33
)

option = from_dict(OptionB, d)

@testset "options" begin
    @test option == OptionB(;
        opt = OptionA(;
            name = "Roger",
            int = 2,
        ),
        float = 0.33,
    )

    @test from_toml(OptionB, "option.toml") == option
end

@testset "to_dict" begin
    @test_throws ErrorException to_dict("aaa")
    @test to_dict(option) == d
    @test to_toml(option) == "float = 0.33\n\n[opt]\nname = \"Roger\"\nint = 2\n"
end

@testset "default reflection" begin
    @test field_defaults(OptionA) == [no_default, 1]
    @test field_defaults(OptionB) == [OptionA("Sam", 1), 0.3]
    @test field_default(OptionA, :name) === no_default
    @test field_default(OptionA, :int) == 1
end

@testset "from_kwargs" begin
    @test Configurations.from_kwargs(OptionB; opt_name="Roger", opt_int=2, float=0.33) == option
end

@option struct OptionC
    num::Float64

    function OptionC(num::Float64)
        num > 0 || error("not positive")
        new(num)
    end
end

@testset "inside constructor" begin
    @test_throws ErrorException OptionC(-1.0)
end

@option struct OptionD
    opt::Union{OptionA, OptionB}
end

@testset "test multi option type" begin
    d1 = OrderedDict{String, Any}(
        "opt" => OrderedDict{String, Any}(
            "option_b" => d
        )
    )

    @test from_dict(OptionD, d1).opt isa OptionB

    d2 = OrderedDict{String, Any}(
        "opt" => OrderedDict{String, Any}(
            "option_a" => OrderedDict{String, Any}(
                "name" => "Roger",
                "int" => 2,
            ),
        )
    )

    @test from_dict(OptionD, d2).opt isa OptionA

    d3 = OrderedDict{String, Any}(
        "opt" => OrderedDict{String, Any}(
            OrderedDict{String, Any}(
                "name" => "Roger",
                "int" => 2,
            ),
        )
    )

    @test_throws ErrorException from_dict(OptionD, d3)
end

@option struct OptionE
    field::Union{Nothing, OptionA} = nothing
end

@testset "optional field" begin
    d = OrderedDict{String, Any}(
        "float" => 0.33
    )

    @test from_dict(OptionB, d) == OptionB(;
        opt = OptionA(;
            name = "Sam",
            int = 1,
        ),
        float = 0.33,
    )

    @test from_kwargs(OptionE) == OptionE(;
        field = nothing,
    )
end

@testset "validate keys" begin
    @test_throws ArgumentError Configurations.validate_keywords(OptionA; abc=2)
    @test Configurations.validate_keywords(OptionB; opt_name="AAA") === nothing
    @test_throws ArgumentError Configurations.validate_keywords(OptionB; opt_abc="AAA")
end

@testset "dict override" begin
    d = OrderedDict{String, Any}(
        "opt" => OrderedDict{String, Any}(
            "name" => "Roger",
            "int" => 2,
        ),
        "float" => 0.33
    )

    @test from_dict(OptionB, d; opt_name = "AAA") == OptionB(;
        opt = OptionA(;
            name = "AAA",
            int = 1,
        ),
        float = 0.33,
    )
end

@option mutable struct Julia
    active::Union{String, Nothing} = nothing
    stable::Union{String, Nothing} = nothing
    # NOTE: we store nightly here too
    versions::Dict{VersionNumber, String} = Dict{VersionNumber, String}()
end

@option mutable struct Ion
    julia::Julia = Julia()
end

@testset "non-dict value conversion" begin
    d = Dict{String, Any}(
        "julia" => Dict{String, Any}(
            "active" => "some/path/to/active",
            "stable" => "1.5.3",
            "versions" => Dict{String, String}(
                "1.5.3" => "some/path/to/1.5.3",
            )
        ),
    )

    @test_throws MethodError from_dict(Ion, d)

    function Configurations.option_convert(::Type{Julia}, ::Type{Dict{VersionNumber,String}}, x::Dict{String,String})
        d = Dict{VersionNumber, String}()
        for (k, v) in x
            d[VersionNumber(k)] = v
        end
        return d
    end

    @test from_dict(Ion, d) == Ion(;
        julia = Julia(;
            active = "some/path/to/active",
            stable = "1.5.3",
            versions = Dict(v"1.5.3" => "some/path/to/1.5.3"),
        ),
    )
end

@testset "to_dict nothing conversion" begin
    d = to_dict(Julia())
    @test haskey(d, "versions")
    @test !haskey(d, "active")
end

function foo(::Type{T}) where T
    return 1.0
end

function foo(::Type{Int})
    return 2
end

@option struct Inferrable{A, B}
    a::A
    b::B = 1.0
end

@option struct NotInferrable1{T}
    a::Float64
    b::Int
end

@option struct NotInferrable2{T}
    a::T = foo(T)
    b::Int
end

@option struct NotInferrable3{T}
    a::Float64 = foo(T)
    b::Int
end

@testset "parametric types" begin
    @test Inferrable(;a = 1) == Inferrable(1, 1.0)
    @test_throws ErrorException field_defaults(Inferrable)
    @test field_defaults(Inferrable{Float64, Float64}) == Any[no_default, 1.0]
    @test field_default(Inferrable{Float64, Float64}, :a) === no_default
    @test_throws ErrorException field_default(Inferrable, :a) === no_default
    @test_throws ErrorException field_default(Inferrable, :a)
    @test_throws MethodError NotInferrable1(;a = 1.0, b = 1)
    @test NotInferrable1{Int}(;a = 1.0, b = 1) == NotInferrable1{Int64}(1.0, 1)
    @test_throws MethodError NotInferrable2(;a = 1.0, b = 2)
    @test NotInferrable2{Float64}(;b=2) == NotInferrable2(1.0, 2)
    @test_throws MethodError NotInferrable3(;a = 1.0, b = 1)
    @test field_default(NotInferrable2{Int}, :a) == 2
    @test field_default(NotInferrable2{Float64}, :a) == 1.0
    @test NotInferrable3{Int}(;b = 2) == NotInferrable3{Int}(2.0, 2)   
end

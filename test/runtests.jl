using Configurations
using Configurations: to_dict, to_toml, from_kwargs, from_dict, from_toml
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

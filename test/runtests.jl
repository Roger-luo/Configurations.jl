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

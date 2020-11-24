using Configurations
using Configurations: to_dict, to_toml, from_kwargs, from_dict, from_toml
using OrderedCollections
using Test

"Option A"
@option struct OptionA
    name::String
    int::Int = 1
end

"Option B"
@option struct OptionB
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

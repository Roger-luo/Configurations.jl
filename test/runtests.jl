using Configurations
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

option = OptionB(d)

@testset "options" begin
    @test option == OptionB(;
        opt = OptionA(;
            name = "Roger",
            int = 2,
        ),
        float = 0.33,
    )

    @test OptionB("option.toml") == option
end

@testset "to_dict" begin
    @test_throws ErrorException Configurations.to_dict("aaa")
    @test Configurations.to_dict(option) == d
    @test Configurations.to_toml(option) == "float = 0.33\n\n[opt]\nname = \"Roger\"\nint = 2\n"
end

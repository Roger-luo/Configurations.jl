module TestError

using Test
using Configurations

Base.@kwdef struct OptionA
    x::Int = 1
end

Configurations.is_option(::Type{OptionA}) = true
Configurations.is_option(::OptionA) = true

@testset "error" begin
    @test_throws ErrorException from_dict(OptionA, Dict{String, Any}("x" => 1))    
end

end

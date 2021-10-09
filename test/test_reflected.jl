module Reflected

using Configurations

@option struct OptionA
    type::Reflect
    name::String
    age::Int
end

@option struct OptionB
    type::Reflect
    name::String
end

@option struct OptionC{T}
    type::Reflect
    typevar::T
end

@option struct Composite
    person::Union{OptionA, OptionB, OptionC}
end

end

@testset "Reflect Type" begin
    @testset "OptionA" begin
        opt = Reflected.OptionA(Reflect(), "Sam", 2)
        @test opt == Reflected.OptionA(;name="Sam", age=2)
        d = to_dict(opt)
        @test from_dict(Reflected.OptionA, d) == opt
    end

    @testset "OptionC{T}" begin
        opt = Reflected.OptionC(Reflect(), 2)
        @test opt == Reflected.OptionC(;typevar=2)
        d = to_dict(opt)

        @test_throws ArgumentError from_dict(Reflected.OptionC, d)
        @test_throws ArgumentError from_dict(Reflected.OptionC{Float32}, d)
        @test from_dict(Reflected.OptionC{Int}, d) == Reflected.OptionC(Reflect(), 2)
    end

    @testset "Composite" begin
        opt = Reflected.Composite(
            Reflected.OptionA(Reflect(), "Sam", 2),
        )

        d = to_dict(opt)
        from_dict(Reflected.Composite, d)

        opt = Reflected.Composite(
            Reflected.OptionB(Reflect(), "Sam"),
        )
        d = to_dict(opt)
        from_dict(Reflected.Composite, d)

        opt = Reflected.Composite(
            Reflected.OptionC(Reflect(), "Sam"),
        )
        d = to_dict(opt)
        from_dict(Reflected.Composite, d)

        d = Dict(
            "person" => Dict{String, Any}(
                "type" => "Main.Reflected.OptionC{Float32}",
                "typevar" => 2
            )
        )
        opt = from_dict(Reflected.Composite, d)
        @test typeof(opt.person) <: Reflected.OptionC{Float32}
    end

    @testset "duplicated Reflect" begin
        ex = @expr struct OptionError
            type_a::Reflect
            type_b::Reflect
            age::Int
        end

        @test_throws ArgumentError Configurations.option_m(Main, ex)

        ex = @expr JLKwStruct struct OptionError
            type_a::Reflect
            type_b::Reflect
            age::Int
        end
        @test has_duplicated_reflect_type(Main, ex)

        ex = @expr JLKwStruct struct OptionB
        end
        @test !has_duplicated_reflect_type(Main ,ex)
    end
end

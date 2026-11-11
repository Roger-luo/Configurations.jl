module TestCoverage

using Test
using Configurations

# runtime union resolution (`from_dict_union_type_dynamic`), reached via vector fields
@option struct CovMaybeVec
    xs::Vector{Maybe{Int}}
end

@option struct CovNoAliasA
    a::Int
end

@option struct CovNoAliasB
    b::String
end

@option struct CovNoAliasVec
    xs::Vector{Union{Nothing, CovNoAliasA, CovNoAliasB}}
end

# union of types whose `Reflect` fields have different names
@option "cov_reflect_a" struct CovReflectA
    type::Reflect
    a::Int = 1
end

@option "cov_reflect_b" struct CovReflectB
    kind::Reflect
    b::Int = 2
end

@option struct CovReflectUnion
    x::Union{CovReflectA, CovReflectB}
end

@testset "union resolution" begin
    @testset "vector of Maybe{T}" begin
        x = from_dict(CovMaybeVec, Dict{String,Any}("xs" => Any[1, nothing, 3]))
        @test isequal(x.xs, [1, nothing, 3])
        @test x == from_dict(CovMaybeVec, to_dict(x))
    end

    @testset "vector of option types without alias or Reflect" begin
        d = Dict{String,Any}("xs" => Any[
            Dict{String,Any}("a" => 1),
            nothing,
            Dict{String,Any}("b" => "s"),
        ])
        x = from_dict(CovNoAliasVec, d)
        @test isequal(x.xs, [CovNoAliasA(1), nothing, CovNoAliasB("s")])

        bad = Dict{String,Any}("xs" => Any[Dict{String,Any}("c" => 1)])
        @test_throws ErrorException from_dict(CovNoAliasVec, bad)
    end

    @testset "union with different Reflect field names" begin
        for v in (CovReflectA(Reflect(), 3), CovReflectB(Reflect(), 4))
            x = CovReflectUnion(v)
            @test from_dict(CovReflectUnion, to_dict(x)) == x
        end
    end
end

@testset "to_dict on a type" begin
    @test_throws ErrorException to_dict(CovNoAliasA, TOMLStyle)
end

end # module

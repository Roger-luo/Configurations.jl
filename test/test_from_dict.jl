module TestFromDict

using Test
using Configurations
using Configurations: from_dict_union_type_dynamic

@option "option_a" struct OptionAliasA
    x::Int = 1
    y::Int = 2
end

@option struct IgnoreExtra
    x::Int = 1
    y::Int = 2
end

Configurations.ignore_extra(::Type{IgnoreExtra}) = true

@option "option_b" struct OptionAliasB
    x::Int = 1
end

@option "option_c" struct OptionAliasC
    y::Int = 1
end

@option struct OptionReflectA
    type::Reflect
    x::Int = 1
    y::Int = 2
end

@option struct OptionReflectB
    type::Reflect
    x::Int = 1
end

@option struct OptionReflectC
    type::Reflect
    y::Int = 1
end

@option "option_type" struct ReflectWithAlias
    type::Reflect
    y::Int = 1
end

@option struct TestUnionType
    maybe_reflect::Maybe{OptionReflectA}
    maybe_alias::Maybe{OptionAliasA}
    union_of_alias::Union{OptionAliasA,OptionAliasB,OptionAliasC}
    union_of_reflects::Union{OptionReflectA,OptionReflectB,OptionReflectC}
    maybe_of_alias::Maybe{Union{OptionAliasA,OptionAliasB,OptionAliasC}}
    maybe_of_reflects::Maybe{Union{OptionReflectA,OptionReflectB,OptionReflectC}}
    totally_mixed::Union{OptionAliasA,OptionAliasB,OptionReflectA,OptionReflectB}
    maybe_totally_mixed::Maybe{
        Union{OptionAliasA,OptionAliasB,OptionReflectA,OptionReflectB}
    }
end

@testset "from_dict" begin
    @testset "ignore_extra" begin
        d = Dict{String, Any}(
            "x" => 1,
            "y" => 2,
            "z" => 3,
        )
        @test_throws InvalidKeyError from_dict(OptionAliasA, d)
        @test from_dict(IgnoreExtra, d) == IgnoreExtra()
    end

    @testset "test maybe union type" begin
        d = Dict{String,Any}(
            "maybe_reflect" => Dict{String,Any}(),
            "maybe_alias" => Dict{String,Any}(),
            "union_of_alias" => Dict{String,Any}("option_b" => Dict{String,Any}("x" => 1)),
            "union_of_reflects" =>
                Dict{String,Any}("type" => "Main.TestFromDict.OptionReflectC", "y" => 1),
            "maybe_of_alias" => nothing,
            "maybe_of_reflects" => nothing,
            "totally_mixed" =>
                Dict{String,Any}("type" => "Main.TestFromDict.OptionReflectB", "x" => 1),
            "maybe_totally_mixed" =>
                Dict{String,Any}("option_a" => Dict{String,Any}("x" => 1, "y" => 2)),
        )
        option = TestUnionType(;
            union_of_alias=OptionAliasB(),
            union_of_reflects=OptionReflectC(),
            totally_mixed=OptionReflectB(),
            maybe_totally_mixed=OptionAliasA(),
        )
        @test from_dict(TestUnionType, d) == option
    end

    @testset "test dynamic union type" for option in [
        TestUnionType(;
            maybe_reflect=OptionReflectA(),
            maybe_alias=OptionAliasA(),
            union_of_alias=OptionAliasB(),
            union_of_reflects=OptionReflectC(),
            maybe_of_alias=OptionAliasB(),
            maybe_of_reflects=OptionReflectC(),
            totally_mixed=OptionReflectB(),
            maybe_totally_mixed=OptionAliasA(),
        ),
        TestUnionType(;
            maybe_reflect=OptionReflectA(),
            maybe_alias=OptionAliasA(),
            union_of_alias=OptionAliasA(),
            union_of_reflects=OptionReflectB(),
            maybe_of_alias=OptionAliasA(),
            maybe_of_reflects=OptionReflectB(),
            totally_mixed=OptionAliasA(),
            maybe_totally_mixed=OptionReflectB(),
        ),
    ]
        d = to_dict(option)
        @test from_dict(TestUnionType, d) == option

        for idx in 1:fieldcount(TestUnionType)
            field = fieldname(TestUnionType, idx)
            type = fieldtype(TestUnionType, idx)
            types = Base.uniontypes(type)
            if Nothing in types
                type = Union{filter(x -> x !== Nothing, types)...}
            end
            @test from_dict_union_type_dynamic(
                TestUnionType, OptionField(field), type, d[string(field)]
            ) == getfield(option, field)
        end
    end
end

end # TestFromDict

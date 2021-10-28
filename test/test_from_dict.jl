module TestFromDict

using Test
using Configurations
using Configurations: from_dict_union_type_dynamic

@option "option_a" struct OptionAliasA
    x::Int = 1
    y::Int = 2
end

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

@option struct TestUnionType
    maybe_reflect::Maybe{OptionReflectA}
    maybe_alias::Maybe{OptionAliasA}
    union_of_alias::Union{OptionAliasA, OptionAliasB, OptionAliasC}
    union_of_reflects::Union{OptionReflectA, OptionReflectB, OptionReflectC}
    maybe_of_alias::Maybe{Union{OptionAliasA, OptionAliasB, OptionAliasC}}
    maybe_of_reflects::Maybe{Union{OptionReflectA, OptionReflectB, OptionReflectC}}
    totally_mixed::Union{OptionAliasA, OptionAliasB, OptionReflectA, OptionReflectB}
    maybe_totally_mixed::Maybe{Union{OptionAliasA, OptionAliasB, OptionReflectA, OptionReflectB}}
end

@testset "test dynamic from_dict" begin
    opt1 = TestUnionType(
        maybe_reflect = OptionReflectA(),
        maybe_alias = OptionAliasA(),
        union_of_alias = OptionAliasB(),
        union_of_reflects = OptionReflectC(),
        maybe_of_alias = OptionAliasB(),
        maybe_of_reflects = OptionReflectC(),
        totally_mixed = OptionReflectB(),
        maybe_totally_mixed = OptionAliasA(),
    )
    
    d = to_dict(opt1)
    from_dict(TestUnionType, d)

    for idx in 1:fieldcount(TestUnionType)
        field = fieldname(TestUnionType, idx)
        type = fieldtype(TestUnionType, idx)
        types = Base.uniontypes(type)
        if Nothing in types
            type = Union{filter(x->x!==Nothing, types)...}
        end
        @test from_dict_union_type_dynamic(
            TestUnionType,
            OptionField(field),
            type, d[string(field)]) == getfield(opt1, field)
    end        
end

end # TestFromDict

using Test
using Configurations
using Configurations: from_dict_union_type_dynamic


opt1 = TestFromDict.TestUnionType(
        maybe_reflect = TestFromDict.OptionReflectA(),
        maybe_alias = TestFromDict.OptionAliasA(),
        union_of_alias = TestFromDict.OptionAliasB(),
        union_of_reflects = TestFromDict.OptionReflectC(),
        maybe_of_alias = TestFromDict.OptionAliasB(),
        maybe_of_reflects = TestFromDict.OptionReflectC(),
        totally_mixed = TestFromDict.OptionReflectB(),
        maybe_totally_mixed = TestFromDict.OptionAliasA(),
    )
    
    d = to_dict(opt1)

from_dict_union_type_dynamic(
    TestFromDict.TestUnionType,
    OptionField(:maybe_alias),
    Maybe{TestFromDict.OptionAliasA}, d["maybe_alias"]
)

using Configurations
using Expronicon
using Expronicon.Types
using Expronicon.CodeGen

ex = :(struct OptionB
opt::OptionA
float::Float64 = sin(opt)
end)


@option struct OptionB
    opt::OptionA
    float::Float64 = 2.0
end

codegen_ast(JLKwStruct(ex))
jl = JLKwStruct(ex)
Configurations.codegen_field_default(jl)

OptionB(opt=OptionA(name="A"))

using Options
using Options: option_m
using Test

@option struct OptionB
    version::VersionNumber = v"0.1.0"
end

"""
Option A
"""
@option struct OptionA
    str::String = "string"
    int::Int = 1
    bool::Bool = false
    other::OptionB = OptionB()
end

ex = :(
    struct OptionA
        str::String = "string"
        int::Int = 1
        bool::Bool = false
        other::OptionB = OptionB()
    end
)

ex = :(
    struct OptionA{T}
        str::String = "string"
        int::T = 1
        bool::Bool = false
        other::OptionB = OptionB()
    end
)

option_m(ex)

d = Dict(
    "str" => "a string",
    "int" => 2
)
Options.from_dict(OptionA, d)

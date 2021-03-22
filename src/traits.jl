struct NotOption end
struct IsaOption end

"""
    is_option(x)

Check if `x` is an option type or not.
"""
is_option(x) = false

"""
    compare_options(a, b, xs...)::Bool

Compare option types check if they are the same.
"""
function compare_options(a, b, xs...)::Bool
    compare_options(a, b) || return false
    compare_options(b, xs...)
end

compare_options(a, b) = false

function compare_options(a::A, b::A) where {A}
    for each in fieldnames(A)
        getfield(a, each) == getfield(b, each) || return false
    end
    return true
end

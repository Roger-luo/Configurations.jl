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
    is_option(A) || return a == b # fall through to normal compare
    for idx in 1:nfields(a)
        compare_options(getfield(a, idx), getfield(b, idx)) || return false
    end
    return true
end

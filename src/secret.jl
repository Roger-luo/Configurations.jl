"""
    Secret{T}
    Secret(value)

A wrapper for sensitive values (e.g passwords, API tokens) in option types.
A `Secret` is always printed masked as `Secret("********")`, so the wrapped
value does not leak into logs, error messages or the REPL when the whole
option type is printed. Use [`reveal`](@ref) to access the wrapped value.

Parsing (`from_dict`, `from_toml`, keyword constructors) wraps plain values
into `Secret` automatically, and serialization (`to_dict`, `to_toml`) writes
the **real** value so that configurations round-trip.

!!! warning
    `Secret` only prevents accidental printing. The value is still stored
    in memory as is, and is visible to tools that inspect fields directly
    (e.g `dump`), as well as in the output of `to_dict` and `to_toml`.

# Example

```julia-repl
julia> @option struct Database
           user::String = "admin"
           password::Secret{String}
       end

julia> db = from_dict(Database, Dict("password" => "hunter2"))
Database("admin", Secret("********"))

julia> reveal(db.password)
"hunter2"
```
"""
struct Secret{T}
    value::T
end

"""
    reveal(s::Secret)

Return the value wrapped in the [`Secret`](@ref) `s`.
"""
reveal(s::Secret) = s.value

Base.show(io::IO, ::Secret) = print(io, "Secret(\"********\")")
Base.:(==)(a::Secret, b::Secret) = a.value == b.value
Base.isequal(a::Secret, b::Secret) = isequal(a.value, b.value)
Base.hash(s::Secret, h::UInt) = hash(s.value, hash(Secret, h))

Base.convert(::Type{Secret{T}}, s::Secret{T}) where {T} = s
Base.convert(::Type{Secret{T}}, s::Secret) where {T} = Secret{T}(convert(T, s.value))
Base.convert(::Type{Secret{T}}, x) where {T} = Secret{T}(convert(T, x))
Base.convert(::Type{Secret}, s::Secret) = s
Base.convert(::Type{Secret}, x) = Secret(x)

# NOTE: parse the wrapped value with the usual conversion rules of the
# option type, so user overloads and nested option types keep working
from_dict(::Type{OptionType}, ::Type{Secret{T}}, s::Secret) where {OptionType,T} =
    convert(Secret{T}, s)
from_dict(::Type{OptionType}, ::Type{Secret{T}}, x) where {OptionType,T} =
    Secret{T}(from_dict(OptionType, T, x))
from_dict(::Type, ::Type{Secret}, x) = convert(Secret, x)

to_dict(::Type{T}, s::Secret, option::ToDictOption) where {T} = to_dict(T, s.value, option)

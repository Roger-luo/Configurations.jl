"maybe of type `T` or nothing"
const Maybe{T} = Union{Nothing, T}

"""
    PartialDefault{F}

Type for non-constant default value, it depends on the value of another field that has default value.
"""
struct PartialDefault{F}
    lambda::F
    vars::Vector{Symbol}
    expr::Expr
end

(f::PartialDefault)(x) = f.lambda(x)

function Base.show(io::IO, x::PartialDefault)
    print(io, JLFunction(;head=:->, args=x.vars, body=x.expr))
end

"""
    Reflect

Placeholder type for reflected type string.

# Example

the following option struct

```julia
@option struct MyOption
    type::Reflect
    name::String = "Sam"
end
```

would be equivalent to

```toml
type = "MyOption"
name = "Sam"
```

this is useful for defining list of different types etc.
"""
struct Reflect end

"""
    create(::Type{T}; kwargs...) where T
    
Create an instance of option type `T` from `kwargs`. Similar
to the default keyword argument constructor, but one can use this to create
custom keyword argument constructor with extra custom keywords.
"""
function create(::Type{T}; kwargs...) where T
    error("$T is not an option type")
end

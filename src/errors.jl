struct DuplicatedAliasError <: Exception
    name::String
end

function Base.show(io::IO, err::DuplicatedAliasError)
    print(io, "duplicated alias name: ")
    printstyled(io, err.name; color=:cyan)
end

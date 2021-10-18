struct DuplicatedAliasError <: Exception
    name::String
end

function Base.showerror(io::IO, err::DuplicatedAliasError)
    print(io, "duplicated alias name: ")
    printstyled(io, err.name; color=:cyan)
end

struct InvalidKeyError <: Exception
    got::Symbol
    keys::Vector{Symbol}
end

function Base.showerror(io::IO, err::InvalidKeyError)
    print(io, "invalid key ")
    printstyled(io, err.got; color=:light_blue)
    print(io, ", possible keys are: ")

    if length(err.keys) > 8
        for idx in 1:8
            printstyled(io, err.keys[idx]; color=:light_blue)
            if idx != 8
                print(io, ", ")
            end
        end
        print(io, "... please check documentation for other valid keys")
    else
        for idx in eachindex(err.keys)
            printstyled(io, err.keys[idx]; color=:light_blue)
            if idx != lastindex(err.keys)
                print(io, ", ")
            end
        end
    end
    return
end

"""
    DuplicatedFieldError(name, type)

A field with `name` of given option `type` is duplicated in the subfields option type.
Thus one cannot use the field keyword convention when seeing this error.
"""
struct DuplicatedFieldError <: Exception
    name::Symbol
    type
end

function Base.showerror(io::IO, err::DuplicatedFieldError)
    print(io, "duplicated field ")
    printstyled(io, err.name; color=:light_blue)
    print(io, " in type ")
    printstyled(io, err.type; color=:green)
    print(io, " and its sub-fields")
end

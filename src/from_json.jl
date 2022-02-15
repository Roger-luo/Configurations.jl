
"""
from_json(::Type{T}, filename::String; kw...) where T

Convert a given JSON file `filename` to an option type `T`. Valid fields
can be override by keyword arguments. See also [`from_dict`](@ref).
"""
function from_json(::Type{T}, filename::String; kw...) where {T}
is_option(T) || error("not an option type")
d = JSON.parse(read(open(filename), String))

filepath = normpath(filename)
d["#metadata#"] = Dict{String, Any}(
    "file" => filepath,
    "dir" => dirname(filepath),
    "format" => "JSON",
)
return from_dict(T, d; kw...)
end

"""
from_json_if_exists(::Type{T}, filename::String; kw...) where T

Similar to [`from_json`](@ref) but will create the option instance
via `from_kwargs(T;kw...)` instead of error if the file does not exist.
"""
function from_json_if_exists(::Type{T}, filename::String; kw...) where {T}
if isfile(filename)
    return from_json(T, filename; kw...)
else
    return from_kwargs(T; kw...)
end
end

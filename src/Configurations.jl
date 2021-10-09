module Configurations

export @option, from_dict, from_kwargs, from_toml, to_dict, to_toml

using TOML
using ExproniconLite
using OrderedCollections

export no_default,
    Maybe,
    Reflect,
    # reflection
    field_default,
    # field_alias,
    type_alias,
    # traits
    is_option,
    # parse
    from_dict,
    from_kwargs,
    from_toml,
    from_toml_if_exists,
    # serialize
    to_dict,
    DuplicatedFieldError,
    DuplicatedAliasError,
    InvalidKeyError,
    TOMLStyle,
    YAMLStyle,
    JSONStyle

@static if VERSION < v"1.1"
    function fieldtypes(T::Type)
        ntuple(fieldcount(T)) do idx
            fieldtype(T, idx)
        end
    end
end

include("types.jl")
include("convert.jl")
include("reflection.jl")
include("utils.jl")
include("parse.jl")
include("codegen.jl")

include("serialize.jl")


end

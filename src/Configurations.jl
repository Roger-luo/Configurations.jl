module Configurations

export @option, from_dict, from_kwargs, from_toml, to_dict, to_toml

using TOML
using ExproniconLite
using OrderedCollections

using Crayons.Box

export no_default,
    Maybe,
    # reflection
    field_aliases,
    field_default,
    field_alias,
    type_alias,
    # traits
    is_option,
    # parse
    from_dict,
    from_kwargs,
    from_toml,
    from_toml_if_exists,
    # serialize
    to_dict

include("types.jl")
include("convert.jl")
include("reflection.jl")
include("utils.jl")
include("parse.jl")
include("codegen.jl")

include("serialize.jl")


end

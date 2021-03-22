module Configurations

export @option, from_dict, from_kwargs, from_toml, to_dict, to_toml

using TOML
using Expronicon
using OrderedCollections

using Crayons.Box
using Expronicon.Types
using Expronicon.Analysis
using Expronicon.CodeGen
using Expronicon.Transform
using Expronicon.Printings

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
    # serialize
    to_dict

include("types.jl")
include("convert.jl")
include("reflection.jl")
include("traits.jl")
include("parse.jl")
include("codegen.jl")
include("serialize.jl")
include("printing.jl")

end

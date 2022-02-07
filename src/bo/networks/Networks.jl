module Networks

# using ..AmplTxt

include("./generator.jl")
include("./bus.jl")
include("./branch.jl")
include("./network.jl")

function get_id(obj)
    return obj.id
end

export
    # struct
    Generator, Bus, Branch, Network,
    # functions
    ## bus
    add_new_bus!, add_new_buses!, add_bus!, add_buses!,
    get_bus, safeget_bus, get_buses,
    get_loads, get_generators,
    ## branch
    add_new_branch!, add_new_branches!, add_branch!, add_branches!,
    get_branch, safeget_branch, get_branches,
    ## load and generator
    add_new_load_to_bus!, add_new_generator_to_bus!,
    get_load, safeget_load, get_loads,
    get_generator, safeget_generator, get_generators,
    ## infos
    get_info

end #module Networks

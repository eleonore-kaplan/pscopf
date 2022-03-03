module Data

using ..PSCOPFio
using ..Networks

export
    pscopfdata2network



#################
# from pscopf_
#################


function pscopfdata2network(data::String)::Network
    # Init network
    network = Networks.Network(data)

    #from pscopf_ptdf
    PSCOPFio.read_buses!(network, data)
    #from pscopf_ptdf and pscopf_limits
    PSCOPFio.read_branches!(network, data)
    #from pscopf_ptdf
    PSCOPFio.read_ptdf!(network, data)

    #from pscopf_units and pscopf_gen_type_bus
    PSCOPFio.read_generators!(network, data)

    # Return built network
    return network
end

end

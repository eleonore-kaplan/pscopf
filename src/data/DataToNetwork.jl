module Data

using ..PSCOPFio
using ..Networks

export
    pscopfdata2network



#################
# from pscopf_
#################


"""
    pscopfdata2network(data::String)::Network

reads the input files and construct a `PSCOPF.Network`

# Arguments
    - `data::String` : path to the directory containing PSCOPF's input files

# Returns
    The Network representing the input files
"""
function pscopfdata2network(data::String)::Network
    # Init network
    network = Networks.Network(data)

    #from pscopf_ptdf
    PSCOPFio.read_buses!(network, data)
    #from pscopf_ptdf and pscopf_limits
    PSCOPFio.read_branches!(network, data)
    #from pscopf_ptdf
    PSCOPFio.read_ptdf!(network, data)

    #from pscopf_units
    PSCOPFio.read_generators!(network, data)

    # Return built network
    return network
end

end

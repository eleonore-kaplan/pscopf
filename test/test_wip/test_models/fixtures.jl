module PSCOPFFixtures

using PSCOPF

using Dates
using DataStructures
using Printf

"""
creates a network with 2 buses
"""
function network_2buses(;limit::Float64=35., ptdf1=0.5, ptdf2=-0.5)
    network = PSCOPF.Networks.Network()
    # Buses
    PSCOPF.Networks.add_new_bus!(network, "bus_1")
    PSCOPF.Networks.add_new_bus!(network, "bus_2")
    # Branches
    PSCOPF.Networks.add_new_branch!(network, "branch_1_2", limit);
    # PTDF
    PSCOPF.Networks.add_ptdf_elt!(network, "branch_1_2", "bus_1", ptdf1)
    PSCOPF.Networks.add_ptdf_elt!(network, "branch_1_2", "bus_2", ptdf2)

    return network
end



end #module PSCOPFFixtures


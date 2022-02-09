module Data

using ..PSCOPFio
using ..Networks

export
    #data2network
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


#################
# from AMPLTXT
#################
#=


function readAmplData(data::String)
    return AmplTxt.read(data)
end

function add_buses!(network::Network, amplTxt) # c'est quoi le type de amplTxt exactement ?
    buses = amplTxt["buses"];
    for bus in buses.data
        num = parse(Int, bus[2]);
        add_new_bus!(network, num);
        # TODO : ajouter ces attributs en plus
        # numCC = parse(Int, bus[4]);
        # if numCC == 0
        #     id = get_or_add(num, network.bus_to_i);
        #     push!(network.buses, id => Bus(num, bus[11]));
        #     network.CC0[num] = 1;
        # end
    end
end

function add_branches!(network::Network, amplTxt) # c'est quoi le type de amplTxt exactement ?
    branches = amplTxt["branches"];
    for branch in branches.data
        num  = parse(Int, branch[2]);
        bus_src = parse(Int, branch[3]);
        bus_dst = parse(Int, branch[4]);
        add_new_branch!(network, bus_src, bus_dst);

        # TODO : reprendre tout ca
        # on_CC0 = haskey(network.CC0, num_or) && haskey(network.CC0, num_ex);
        # if on_CC0 && num_or != -1  && num_ex != -1
        #     id = get_or_add(num, network.branch_to_i);
        #     ior = get_or_add(num_or, network.bus_to_i);
        #     iex = get_or_add(num_ex, network.bus_to_i);
        #     r = parse(Float64, branch[8]);
        #     x = parse(Float64, branch[9]);
        #     push!(network.branches, id => Branch(ior, iex, r, x, branch[26]));
        # end
    end
end

function add_generators!(network::Network, amplTxt)
    generators = amplTxt["generators"];
    for generator in generators.data
        id = generator[20];
        bus = parse(Int, generator[3]);
        add_new_generator_to_bus!(network, bus, id)

        # TODO : ajouter ces attributs
        # conbus = parse(Int, generator[4]);
        # minP = parse(Float64, generator[6]);
        # maxP = parse(Float64, generator[7]);
    end
end

function add_loads!(network::Network, amplTxt)
    loads = amplTxt["loads"];
    for load in loads.data
        id = load[9];
        bus = parse(Int, load[3]);
        add_new_load_to_bus!(network, bus, id)

        # TODO : ajouter ces attributs
        # p = parse(Float64, load[11]);
        # bus_load[bus] = get(bus_load, bus, 0) + p;
    end
end

function data2network(data::String)::Network
    # Read data
    amplTxt = readAmplData(data)
    # Init network
    network = Networks.Network(data)
    # add buses
    add_buses!(network, amplTxt)
    # add branches
    add_branches!(network, amplTxt)
    # add generators
    add_generators!(network, amplTxt)
    # add loads
    add_loads!(network, amplTxt)
    # Return built network
    return network
end

=#

end

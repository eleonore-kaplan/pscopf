module Data

using ..AmplTxt
using ..PSCOPFio
using ..Networks

using Dates

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
    read_buses!(network, data)
    #from pscopf_ptdf and pscopf_limits
    read_branches!(network, data)
    #from pscopf_ptdf
    read_ptdf!(network, data)

    #from pscopf_units and pscopf_gen_type_bus
    read_generators!(network, data)

    # Return built network
    return network
end

function read_buses!(network::Network, data::String)
    buses_ids = Set{String}();
    open(joinpath(data, "pscopf_ptdf.txt"), "r") do file
        for ln in eachline(file)
            # don't read commentted line
            if ln[1] != '#'
                buffer = AmplTxt.split_with_space(ln);
                push!(buses_ids, buffer[2])
            end
        end
    end

    Networks.add_new_buses!(network, collect(buses_ids));
end

function read_branches!(network::Network, data::String)
    branches = Dict{String,Float64}();
    default_limit = 0.
    open(joinpath(data, "pscopf_ptdf.txt"), "r") do file
        for ln in eachline(file)
            # don't read commentted line
            if ln[1] != '#'
                buffer = AmplTxt.split_with_space(ln);
                branch_id = buffer[1]
                push!(branches, branch_id => default_limit)
            end
        end
    end

    open(joinpath(data, "pscopf_limits.txt"), "r") do file
        for ln in eachline(file)
            # don't read commentted line
            if ln[1] != '#'
                buffer = AmplTxt.split_with_space(ln);
                branch_id = buffer[1]
                limit = parse(Float64, buffer[2]);
                push!(branches, branch_id=>limit)
            end
        end
    end

    for (id,limit) in branches
        Networks.add_new_branch!(network, id, limit);
    end
end

function read_ptdf!(network::Network, data::String)
    open(joinpath(data, "pscopf_ptdf.txt"), "r") do file
        for ln in eachline(file)
            # don't read commentted line
            if ln[1] != '#'
                buffer = AmplTxt.split_with_space(ln);
                branch_id = buffer[1]
                bus_id = buffer[2]
                ptdf_value = parse(Float64, buffer[3])
                Networks.add_ptdf_elt(network, branch_id, bus_id, ptdf_value)
            end
        end
    end
end

function read_generators!(network, data)
    gen_type_bus = Dict{String, Tuple{String, String}}()
    open(joinpath(data, "pscopf_gen_type_bus.txt"), "r") do file
        for ln in eachline(file)
            # don't read commentted line
            if ln[1] != '#'
                buffer = AmplTxt.split_with_space(ln);
                gen_type_bus[buffer[1]] = (buffer[2], buffer[3])
            end
        end
    end

    open(joinpath(data, "pscopf_units.txt"), "r") do file
        for ln in eachline(file)
            # don't read commentted line
            if ln[1] != '#'
                buffer = AmplTxt.split_with_space(ln);

                generator_id = buffer[1]
                gen_type = parse(Networks.GeneratorType, gen_type_bus[generator_id][1])
                pmin = parse(Float64, buffer[3])
                pmax = parse(Float64, buffer[4])
                start_cost = parse(Float64, buffer[5])
                prop_cost = parse(Float64, buffer[6])
                dmo = dp = Dates.Minute(parse(Float64, buffer[7]))

                Networks.add_new_generator_to_bus!(network, gen_type_bus[generator_id][2],
                                        generator_id, gen_type, pmin, pmax, start_cost, prop_cost, dmo, dp)
            end
        end
    end
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

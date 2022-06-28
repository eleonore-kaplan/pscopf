"""
    main_ptdf
A main file to generate a PTDF file

Parameters:
    input_path : path to input data directory describing a grid
                (not the pscopf_ files but branches.txt and buses.txt)
"""

using Graphs
using MetaGraphs
using Printf

root_path = dirname(@__DIR__)
push!(LOAD_PATH, root_path);
cd(root_path)
include(joinpath(root_path, "src", "PTDF.jl"));

MATPOWER_NETWORKS = [
    "case118"
    ,"case1354pegase"
    ,"case13659pegase"
    ,"case14"
    ,"case145"
    ,"case1888rte"
    ,"case1951rte"
    ,"case2383wp"
    ,"case24_ieee_rts"
    ,"case2736sp"
    ,"case2737sop"
    ,"case2746wop"
    ,"case2746wp"
    ,"case2848rte"
    ,"case2868rte"
    ,"case2869pegase"
    ,"case30"
    ,"case300"
    ,"case3012wp"
    ,"case30pwl"
    ,"case30Q"
    ,"case3120sp"
    ,"case3375wp"
    ,"case39"
    ,"case4gs"
    ,"case5"
    ,"case57"
    ,"case6468rte"
    ,"case6470rte"
    ,"case6495rte"
    ,"case6515rte"
    ,"case6ww"
    ,"case89pegase"
    ,"case9"
    ,"case9241pegase"
    ,"case9Q"
    ,"case9target"
];

function network2graph(network::PTDF.Network)
    graph::MetaGraph = MetaGraph(SimpleGraph())

    for (_, bus) in sort(network.buses)
        if !add_vertex!(graph, :bus_ref, bus)
            msg_l = @sprintf("error adding vertex of bus %s to the graph", bus.name)
            error(msg_l)
        end
    end

    for (_, branch) in network.branches
        if !add_edge!(graph, branch.from, branch.to, :branch_ref, branch)
            msg_l = @sprintf("could not add edge of branch %s ie (num_bus1:%d,num_bus2:%d) to the graph. Probably a duplicate edge exists",
                            branch.name, network.buses[branch.from].id, network.buses[branch.to].id)
            @warn msg_l
        end
    end

    return graph
end

function write_non_bridges(graph::MetaGraph, file_path::String)
    bridges_l = bridges(graph)
    @info @sprintf("graph contains %d bridges!", length(bridges_l))

    mkpath(dirname(file_path))
    open(file_path, "w") do file
        write(file, @sprintf("#NON_BRIDGES  #nb_bridges=%d\n", length(bridges_l)) )
        for e in edges(graph)
            if !(e in bridges_l)
                edge_name = get_prop(graph, e, :branch_ref).name
                write(file, edge_name*"\n")
            end
        end
    end
end


function compute_non_bridges(input_path::String)
    network = PTDF.read_network(input_path)

    graph = network2graph(network)

    output_path = joinpath(input_path, "pscopf_non_bridges.txt")
    write_non_bridges(graph, output_path)
end


#########################
# MAIN
#########################
function main(dir_names)
    for input_path in dir_names
        @info input_path
        compute_non_bridges(joinpath(@__DIR__, "..", "data_matpower", input_path));
    end
end


#MATPOWER_NETWORKS = ["case14"]
main(MATPOWER_NETWORKS)




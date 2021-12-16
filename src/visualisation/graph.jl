using ..Networks
using Bijections
using Graphs
using GraphPlot


function bus2vertex(network::Network, index::Int)::Bijection{Int, Int}
    bus2vertex = Bijection{Int, Int}()
    for bus in get_buses(network)
        bus2vertex[bus.id] = index
        index += 1
    end
    return bus2vertex
end

function load2vertex(network::Network, index::Int)::Bijection{String, Int}
    buses = get_buses(network)
    load2vertex = Bijection{String, Int}()
    for bus in buses
        for load in get_loads(bus)
            load2vertex[load.id] = index
            index += 1
        end
    end
    return load2vertex
end

function generator2vertex(network::Network, index::Int)::Bijection{String, Int}
    buses = get_buses(network)
    generator2vertex = Bijection{String, Int}()
    for bus in buses
        for generator in get_generators(bus)
            generator2vertex[generator.id] = index
            index += 1
        end
    end
    return generator2vertex
end

function get_adjacency_size(network::Network)::Int
    # Nb of buses + nb of loads + nb of generators
    size::Int = length(get_buses(network)) + length(get_loads(network)) + length(get_generators(network))
    return size
end

function network_adjacency_matrix( network::Network
                                 , bus_vertex::Bijection{Int, Int}
                                 , load_vertex::Bijection{String, Int}
                                 , generator_vertex::Bijection{String, Int})
    adjacency_size = get_adjacency_size(network)
    adjacency = zeros(Int, adjacency_size, adjacency_size)
    # Edges between buses
    for pair_branch in get_branches(network)
        if pair_branch[2] == true # direction de la branche
            branch::Branch = pair_branch[1]
            index_src = bus_vertex[branch.src]
            index_dst = bus_vertex[branch.dst]
            adjacency[index_src, index_dst] = 1
        end
    end
    # Edge from bus to loads
    for load in get_loads(network)
        index_bus = bus_vertex[load.bus_id]
        index_load = load_vertex[load.id]
        adjacency[index_bus, index_load] = 1
    end
    # Edge from generator to loads
    for generator in get_generators(network)
        index_bus = bus_vertex[generator.bus_id]
        index_generator = generator_vertex[generator.id]
        adjacency[index_generator, index_bus] = 1
    end
    # Return
    return adjacency
end

function make_graph_from_network( network::Network
                                , bus_vertex::Bijection{Int, Int}
                                , load_vertex::Bijection{String, Int}
                                , generator_vertex::Bijection{String, Int})::SimpleDiGraph
    # Construct graph from adjacency matrix
    network_adjacency = network_adjacency_matrix(network, bus_vertex, load_vertex, generator_vertex)
    graph = SimpleDiGraph(network_adjacency)
    println(edges(graph))
    return graph
end

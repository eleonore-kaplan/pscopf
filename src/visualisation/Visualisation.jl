module Visualisation

include("./graph.jl")
include("./labels.jl")

using ..Networks
using Graphs
using GraphPlot

export plot_network


function plot_network(network::Network)
    # Map buses ids to vertex ids (increasing ints)
    bus_vertex = bus2vertex(network, 1); nb_buses = length(bus_vertex);
    load_vertex = load2vertex(network, nb_buses + 1); nb_loads = length(load_vertex);
    generator_vertex = generator2vertex(network, nb_buses + nb_loads + 1);
    # Init graph
    graph = make_graph_from_network(network, bus_vertex, load_vertex, generator_vertex)
    # Node labels
    node_labels = get_node_labels(network, bus_vertex, load_vertex, generator_vertex)
    # Node colors
    node_colors = get_node_colors(network, bus_vertex, load_vertex, generator_vertex)
    # Edge labels
    edge_labels = get_edge_labels(network, graph, bus_vertex, load_vertex, generator_vertex)
    # Plot
    gplot(graph, nodelabel=node_labels, nodefillc=node_colors, edgelabel=edge_labels, edgelabeldistx=0.5, edgelabeldisty=0.5)

    # BONUX : pourquoi pas jouer sur la taille des noeuds et des aretes en fonction de ce qui passe dedans
    # mais quand on aura du temps a perdre
end

end

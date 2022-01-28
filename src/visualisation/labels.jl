using ..Networks
using Bijections
using Colors


function get_buses_infos(network::Network, bus_vertex::Bijection{Int, Int})::Vector{String}
    bus_labels = Vector{String}()
    for bus_index in sort(collect(values(bus_vertex)))
        bus::Bus = safeget_bus(network, bus_vertex(bus_index))
        bus_info::String = get_info(bus)
        push!(bus_labels, bus_info)
    end
    return bus_labels
end

function get_loads_infos(network::Network, load_vertex::Bijection{String, Int})
    load_labels = Vector{String}();
    return load_labels
end

function get_generators_infos(network::Network, generator_vertex::Bijection{String, Int})
    generator_labels = Vector{String}();
    for generator_index in sort(collect(values(generator_vertex)))
        generator::Generator = safeget_generator(network, generator_vertex(generator_index))
        generator_info::String = get_info(generator)
        push!(generator_labels, generator_info)
    end
    return generator_labels
end

function get_node_labels( network::Network
                        , bus_vertex::Bijection{Int, Int}
                        , load_vertex::Bijection{String, Int}
                        , generator_vertex::Bijection{String, Int})::Vector{String}
    node_labels = Vector{String}();
    append!(node_labels, get_buses_infos(network, bus_vertex))
    append!(node_labels, get_loads_infos(network, load_vertex))
    append!(node_labels, get_generators_infos(network, generator_vertex))
    return node_labels
end


function get_node_colors( network::Network
                        , bus_vertex::Bijection{Int, Int}
                        , load_vertex::Bijection{String, Int}
                        , generator_vertex::Bijection{String, Int})
    membership = [ones(Int,length(bus_vertex)) ; 2*ones(Int,length(load_vertex)) ; 3*ones(Int,length(generator_vertex))]
    nodecolor = [colorant"blue", colorant"green", colorant"orange"]
    # membership color
    return nodecolor[membership]
end



function get_edge_labels( network::Network
                        , graph::SimpleDiGraph
                        , bus_vertex::Bijection{Int, Int}
                        , load_vertex::Bijection{String, Int}
                        , generator_vertex::Bijection{String, Int})::Vector{String}
    # Init returned lables
    edge_labels = Vector{String}()
    # Usefull infos
    bus_last_index = length(bus_vertex)
    load_last_index = bus_last_index + length(load_vertex)
    generator_last_index = load_last_index + length(generator_vertex)
    # Loop over edges
    for edge in edges(graph)
        src_index = src(edge)
        dst_index = dst(edge)
        # Edge between buses
        if src_index <= bus_last_index && dst_index <= bus_last_index
            branch::Branch = safeget_branch(network, bus_vertex(src_index), bus_vertex(dst_index))[1]
            push!(edge_labels, get_info(branch))
        # Edge between bus and load
        elseif src_index <= bus_last_index && bus_last_index < dst_index && dst_index <= load_last_index
            push!(edge_labels, "load")
        # Edge bewteen bus and generator
        elseif load_last_index < src_index && src_index <= generator_last_index && dst_index <= bus_last_index
            push!(edge_labels, "gen")
        else
            throw( error("Unexpected edge from node ", src_index, " to node ", dst_index) )
        end
    end
    return edge_labels
end

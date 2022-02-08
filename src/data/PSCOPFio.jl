
module PSCOPFio

using ..PSCOPF
using ..AmplTxt
using ..Networks

using Dates
using DataStructures

##########################
#   Readers
##########################

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
                dmo = dp = Dates.Second(parse(Float64, buffer[7]))

                Networks.add_new_generator_to_bus!(network, gen_type_bus[generator_id][2],
                                        generator_id, gen_type, pmin, pmax, start_cost, prop_cost, dmo, dp)
            end
        end
    end
end

function read_uncertainties_distributions(network, data)
    result = Dict{Union{Networks.Bus,Networks.Generator}, PSCOPF.UncertaintyDistribution}()
    open(joinpath(data, "uncertainties_distribution.txt"), "r") do file
        for ln in eachline(file)
            # don't read commentted line
            if ln[1] != '#'
                buffer = AmplTxt.split_with_space(ln);

                id = buffer[1]
                min_value = parse(Float64, buffer[2])
                max_value = parse(Float64, buffer[3])
                mu = parse(Float64, buffer[4])
                sigma = parse(Float64, buffer[5])
                time_factor = parse(Float64, buffer[6])
                cone_effect = parse(Float64, buffer[7])

                key = Networks.safeget_generator_or_bus(network, id)
                result[key] = PSCOPF.UncertaintyDistribution(id, min_value, max_value, mu, sigma, time_factor, cone_effect)
            end
        end
    end

    result = Dict(sort(collect(result), by=x->Networks.get_id(x[1]) ))
    return result
end
##########################
#   Writers
##########################

end #module PSCOPFio

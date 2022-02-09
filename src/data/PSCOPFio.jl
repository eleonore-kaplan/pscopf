
module PSCOPFio

using ..PSCOPF
using ..AmplTxt
using ..Networks

using Dates
using Printf
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

function read_uncertainties(data)
    result = PSCOPF.Uncertainties()
    open(joinpath(data, "pscopf_uncertainties.txt"), "r") do file
        for ln in eachline(file)
            # don't read commentted line
            if ln[1] != '#'
                buffer = AmplTxt.split_with_space(ln)
                # "name", "ts", "ech", "scenario", "value"))
                name = buffer[1]
                ts = Dates.DateTime(buffer[2])
                ech = Dates.DateTime(buffer[3])
                scenario = buffer[4]
                value = parse(Float64, buffer[5])
                PSCOPF.add_uncertainty!(result, ech, name, ts, scenario, value)
            end
        end
    end
    return result
end

##########################
#   Writers
##########################

function write(dir_path::String, network::Networks.Network)
    mkpath(dir_path)
    # if !isdir(dir_path)
    #     mkpath(dir_path)
    # else
    #     msg = @sprintf("data folder `%s` already exists!", dir_path)
    #     error(msg)
    # end
    #units and gen_type_bus
    write(dir_path, network.generators)
    #limits
    write(dir_path, network.branches)
    #ptdf
    write(dir_path, network.ptdf)
end

function write(dir_path::String, generators::SortedDict{String, Networks.Generator})
    output_file_l = joinpath(dir_path, "pscopf_units.txt")
    open(output_file_l, "w") do file_l
        Base.write(file_l, @sprintf("#%24s%16s%16s%16s%16s%16s%16s%16s\n", "name", "p", "minP","maxP", "start", "prop", "dmo", "dp"))
        for (id_l, generator_l) in generators
            Base.write(file_l, @sprintf("%25s%16.8E%16.8E%16.8E%16.8E%16.8E%16.8E%16.8E\n",
                                    Networks.get_id(generator_l),
                                    0., #FIXME : delete input
                                    Networks.get_p_min(generator_l),
                                    Networks.get_p_max(generator_l),
                                    Networks.get_start_cost(generator_l),
                                    Networks.get_prop_cost(generator_l),
                                    Dates.value(Networks.get_dmo(generator_l)),
                                    Dates.value(Networks.get_dp(generator_l))
                                    )
                    )
        end
    end

    output_file_l = joinpath(dir_path, "pscopf_gen_type_bus.txt")
    open(output_file_l, "w") do file_l
        Base.write(file_l, @sprintf("#%24s%16s%25s\n", "name", "type", "bus"))
        for (id_l, generator_l) in generators
            Base.write(file_l, @sprintf("%25s%16s%25s\n",
                                    Networks.get_id(generator_l),
                                    Networks.get_type(generator_l),
                                    Networks.get_bus_id(generator_l),
                                    )
                    )
        end
    end
end

function write(dir_path::String, branches::SortedDict{String, Networks.Branch})
    output_file_l = joinpath(dir_path, "pscopf_limits.txt")
    open(output_file_l, "w") do file_l
        Base.write(file_l, @sprintf("#%24s%16s\n", "branch", "limit"))
        for (id_l, branch_l) in branches
            Base.write(file_l, @sprintf("%25s%16.8E\n",
                                    Networks.get_id(branch_l),
                                    Networks.get_limit(branch_l)
                                    )
                    )
        end
    end
end


function write(dir_path::String, ptdf::SortedDict{String,SortedDict{String, Float64}})
    output_file_l = joinpath(dir_path, "pscopf_ptdf.txt")
    open(output_file_l, "w") do file_l
        Base.write(file_l, @sprintf("#%24s%16s\n", "REF_BUS", "unknown"))
        Base.write(file_l, @sprintf("#%24s%25s%16s\n", "branch", "bus", "value"))
        for (branch_id_l, _) in ptdf
            for (bus_id_l, val_l) in ptdf[branch_id_l]
                Base.write(file_l, @sprintf("%25s%25s%16.8E\n",
                                        branch_id_l,
                                        bus_id_l,
                                        val_l
                                        )
                            )
            end
        end
    end
end

function write(dir_path::String, uncertainties::PSCOPF.Uncertainties)
    output_file_l = joinpath(dir_path, "pscopf_uncertainties.txt")
    open(output_file_l, "w") do file_l

        Base.write(file_l, @sprintf("#%24s%20s%20s%10s%16s\n", "name", "ts", "ech", "scenario", "value"))
        for (ech, _) in uncertainties
            for (nodal_injection_name, _) in uncertainties[ech]
                for (ts, _) in uncertainties[ech][nodal_injection_name]
                    for (scenario, value_l) in uncertainties[ech][nodal_injection_name][ts]
                        Base.write(file_l, @sprintf("%25s%20s%20s%10s%16.8E\n",
                                        nodal_injection_name,
                                        ts,
                                        ech,
                                        scenario,
                                        value_l
                                        )
                            )
                    end
                end
            end
        end

    end
end

end #module PSCOPFio

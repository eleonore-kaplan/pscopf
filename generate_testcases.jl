import Dates
import Distributions
import Random
import Statistics
using Printf;

#======================================================
        Includes
======================================================#

root_path = @__DIR__;
push!(LOAD_PATH, root_path);
cd(root_path);
include(joinpath(root_path, "AmplTxt.jl"));
include(joinpath(root_path, "Workflow.jl"));
include(joinpath(root_path, "scopf_utils.jl"))



#======================================================
        Definitions
======================================================#

mutable struct RandomDataGenerator
    basedata_path_::String;
    units_data_::Dict{String, Vector{Float64}};
    units_types_data_::Dict{String, Vector{String}};
    ptdf_data_::Dict{Tuple{String, String}, Float64};
    #gen,ts,ech => value
    base_values_data_::Dict{Tuple{String, Dates.DateTime, Dates.DateTime}, Float64};
    #lim_gen => maxP, sigma, mu
    uncertain_properties_::Dict{String, Vector{Float64}};

    #gen,ts,ech,s => value
    created_uncertainties_::Dict{Tuple{String, Dates.DateTime, Dates.DateTime, String}, Float64};
    branch_limits_::Dict{String, Float64};
    lst_scenarios_::Vector{String};

end

function RandomDataGenerator(basedata_path_p::String)
    return RandomDataGenerator(basedata_path_p,
                            Workflow.read_units(basedata_path_p),
                            Workflow.read_gen_type_bus(basedata_path_p),
                            Workflow.read_ptdf(basedata_path_p),
                            Workflow.read_previsions(basedata_path_p, "base_values.txt"),
                            read_uncertain_properties(basedata_path_p),
                            Dict{Tuple{String, Dates.DateTime, Dates.DateTime, String}, Float64}(),
                            Dict{String, Float64}(),
                            Vector{String}()
                            )
end

function reset_limits!(data_generator_p::RandomDataGenerator)
    data_generator_p.branch_limits_ = Dict{String, Float64}()

    return data_generator_p
end

function reset!(data_generator_p::RandomDataGenerator)
    data_generator_p.created_uncertainties_ = Dict{Tuple{String, Dates.DateTime, Dates.DateTime, String}, Float64}()
    data_generator_p.lst_scenarios_ = Vector{String}()
    reset_limits!(data_generator_p)

    return data_generator_p
end

#================
Reading functions
================#

function read_uncertain_properties(dir_path_p::String)
    result_l = Dict{String,Vector{Float64}}();
    file_path = joinpath(dir_path_p, "uncertain_properties.txt");
    open(file_path) do file
        for ln in eachline(file)
            # don't read commentted line
            if ln[1] != '#'
                buffer = AmplTxt.split_with_space(ln);
                result_l[buffer[1]] = parse.(Float64, buffer[2:4])
            end
        end
    end
    return result_l;
end

#================
Writing functions
================#

function copy_ready_pscopf_files(basedata_path_p::String, instance_path_p::String)
    files_to_copy = ["pscopf_units.txt", "pscopf_ptdf.txt", "pscopf_gen_type_bus.txt", "pscopf_previsions.txt"]
    for filename_l in files_to_copy
        from_filepath_l = joinpath(basedata_path_p, filename_l)
        to_filepath_l = joinpath(instance_path_p, filename_l)
        cp(from_filepath_l, to_filepath_l)
    end
end

function write_pscopf_uncertainties(output_file_p, data_generator_p::RandomDataGenerator)
    write_pscopf_uncertainties(output_file_p, data_generator_p.created_uncertainties_)
end
function write_pscopf_uncertainties(output_file_p,
                                    created_uncertainties_p::Dict{Tuple{String, Dates.DateTime, Dates.DateTime, String}, Float64})
    open(output_file_p, "w") do file_l
        write(file_l, @sprintf("#%-9s%25s%25s%10s%10s\n", "id", "h_15m", "ech","scenario", "v"))
        for ((id_l,ts_l,ech_l,s_l), val_l) in created_uncertainties_p
            write(file_l, @sprintf("%-10s%25s%25s%10s%10.3f\n", id_l, ts_l, ech_l, s_l, val_l))
        end
    end
end

function write_pscopf_limits(output_file_p, data_generator_p::RandomDataGenerator)
    write_pscopf_limits(output_file_p, data_generator_p.branch_limits_)
end
function write_pscopf_limits(output_file_p,
        branch_limits_p::Dict{String, Float64})
    open(output_file_p, "w") do file_l
        write(file_l, @sprintf("#%-9s%10s\n", "branch", "limit"))
        for (branch_l, lim_l) in branch_limits_p
            write(file_l, @sprintf("%-10s%10.3f\n", branch_l, lim_l))
        end
    end
end

function write_instance(data_generator_p::RandomDataGenerator, instance_path_p::String)
    mkpath(instance_path_p)

    copy_ready_pscopf_files(data_generator_p.basedata_path_, instance_path_p)

    output_l=joinpath(instance_path_p, "pscopf_uncertainties.txt")
    write_pscopf_uncertainties(output_l, data_generator_p)

    output_l=joinpath(instance_path_p, "pscopf_limits.txt")
    write_pscopf_limits(output_l, data_generator_p)
end


#================
    accessors
================#

function get_unit_type(unit_name_p, units_types_data_p)
    if !haskey(units_types_data_p, unit_name_p)
        return nothing
    end
    return units_types_data_p[unit_name_p][1]
end

function is_unit(unit_name_p::String, data_generator_p::RandomDataGenerator)
    return is_unit(unit_name_p, data_generator_p.units_types_data_)
end
function is_unit(unit_name_p::String, units_types_data_p)
    return ( (is_unit_limitable(unit_name_p, units_types_data_p))
            || (is_unit_imposable(unit_name_p, units_types_data_p)) )
end

function is_unit_limitable(unit_name_p::String, data_generator_p::RandomDataGenerator)
    return is_unit_limitable(unit_name_p, data_generator_p.units_types_data_)
end
function is_unit_limitable(unit_name_p::String, units_types_data_p)
    return get_unit_type(unit_name_p, units_types_data_p) == Workflow.K_LIMITABLE
end

function is_unit_imposable(unit_name_p::String, data_generator_p::RandomDataGenerator)
    return is_unit_imposable(unit_name_p, data_generator_p.units_types_data_)
end
function is_unit_imposable(unit_name_p::String, units_types_data_p)
    return get_unit_type(unit_name_p, units_types_data_p) == Workflow.K_IMPOSABLE
end

function get_buses(data_generator_p::RandomDataGenerator)
    return get_buses(data_generator_p.units_types_data_)
end
function get_buses(units_types_data_p)
    return unique([val_i[2] for (_,val_i) in units_types_data_p])
end

function get_branches(data_generator_p::RandomDataGenerator)
    return get_branches(data_generator_p.ptdf_data_)
end
function get_branches(ptdf_data_p::Dict{Tuple{String, String}, Float64})
    return unique([key_i[1] for (key_i,_) in ptdf_data_p])
end

function get_total_base_consumption(random_generator_p::RandomDataGenerator)
    return get_total_base_consumption(random_generator_p.base_values_data_, random_generator_p.units_types_data_)
end
function get_total_base_consumption(base_values_data_p, units_types_data_p)
    #base total consumption by ts,ech
    total_base_consumption_l = Dict{Tuple{Dates.DateTime, Dates.DateTime}, Float64}()
    for ((gen_l,ts_l,ech_l),prev_l) in filter( x -> is_unit(x[1][1], units_types_data_p) , base_values_data_p)
        get!(total_base_consumption_l, (ts_l,ech_l), 0)
        total_base_consumption_l[ts_l,ech_l] += prev_l
    end

    return total_base_consumption_l
end

function get_limitable_base_values(data_generator_p)
    return filter( x -> is_unit_limitable(x[1][1], data_generator_p) , data_generator_p.base_values_data_)
end
function get_imposable_base_values(data_generator_p)
    return filter( x -> is_unit_imposable(x[1][1], data_generator_p) , data_generator_p.base_values_data_)
end

#================================
   Instance creation functions
================================#

function create_scenarios!(data_generator_p::RandomDataGenerator, n_scenarios_p::Int64)
    data_generator_p.lst_scenarios_ = [@sprintf("S%d", x) for x in 1:n_scenarios_p];
    return data_generator_p.lst_scenarios_
end

function create_load!(data_generator_p::RandomDataGenerator,
                    sigma_load_p::Number=0.05,
                    mu_load_p::Number=0.)

    n_scenarios_l = length(data_generator_p.lst_scenarios_)
    total_base_consumption_l = get_total_base_consumption(data_generator_p)

    # suppose buses coeffs do not change with time
    buses_l = get_buses(data_generator_p)
    coeffs_l = rand(length(buses_l))
    coeffs_l = coeffs_l / sum(coeffs_l)
    buses_coeffs_l = Dict(zip(buses_l,coeffs_l))

    # Create random total loads
    random_total_consumption_l = Dict{Tuple{Dates.DateTime, Dates.DateTime, String}, Float64}()
    for ((ts_l,ech_l), load_l) in total_base_consumption_l
        factor_l = max(Dates.value(floor(ts_l - ech_l, Dates.Minute)) / 60, 0)
        adjusted_sigma_load_l = factor_l * sigma_load_p
        rand_deviations_l = rand(Distributions.Normal(mu_load_p, adjusted_sigma_load_l), n_scenarios_l);
        for s in 1:n_scenarios_l
            random_value_l = load_l * (1 + rand_deviations_l[s])
            random_total_consumption_l[ts_l, ech_l, data_generator_p.lst_scenarios_[s]] = max(random_value_l, 0)
        end
    end
    println("random_total_consumption")
    SCOPFutils.pretty_print(random_total_consumption_l, sort_p=true)

    # distribute the total random consumption on buses
    for ((ts_l, ech_l, s_l), total_load_l) in random_total_consumption_l
        for (bus_l,coeff_l) in buses_coeffs_l
            data_generator_p.created_uncertainties_[bus_l,ts_l,ech_l,s_l] = coeff_l * total_load_l
        end
    end

    return data_generator_p.created_uncertainties_
end

function create_limitable_uncertainties!(data_generator_p::RandomDataGenerator)
    n_scenarios_l = length(data_generator_p.lst_scenarios_)

    #Create uncertainties for limitables
    for ((gen_l,ts_l,ech_l),prev_l) in get_limitable_base_values(data_generator_p)
        p_max_l = data_generator_p.uncertain_properties_[gen_l][1]

        sigma_l = data_generator_p.uncertain_properties_[gen_l][2]
        mu_l = data_generator_p.uncertain_properties_[gen_l][3]
        factor_l = max(Dates.value(floor(ts_l - ech_l, Dates.Minute)) / 60, 0)
        adjusted_sigma_l = factor_l * sigma_l
        adjusted_mu_l = factor_l * mu_l

        rand_deviations = rand(Distributions.Normal(adjusted_mu_l, adjusted_sigma_l), n_scenarios_l);
        for s in 1:n_scenarios_l
            rand_value_l = prev_l + rand_deviations[s] * p_max_l
            rand_value_l = min(rand_value_l, p_max_l)
            rand_value_l = max(rand_value_l, 0)
            data_generator_p.created_uncertainties_[gen_l,ts_l,ech_l,data_generator_p.lst_scenarios_[s]] = rand_value_l
        end
    end

    return data_generator_p.created_uncertainties_
end

function create_imposable_uncertainties!(data_generator_p::RandomDataGenerator)
    n_scenarios_l = length(data_generator_p.lst_scenarios_)

    for ((gen_l,ts_l,ech_l),prev_l) in get_imposable_base_values(data_generator_p)
        for s in 1:n_scenarios_l
            data_generator_p.created_uncertainties_[gen_l,ts_l,ech_l,data_generator_p.lst_scenarios_[s]] = prev_l
        end
    end

    return data_generator_p.created_uncertainties_
end

function create_limits!(data_generator_p::RandomDataGenerator)
    total_base_consumption_l = get_total_base_consumption(data_generator_p)
    max_total_power_l = maximum(values(total_base_consumption_l))

    branches_l = get_branches(data_generator_p)
    n_branches_l = length(branches_l)
    n_buses_l = length(get_buses(data_generator_p))
    lst_limits_coeffs_l = [1, 1/n_branches_l, 0.5 * 1 / n_branches_l, 2 * 1 / n_branches_l, 1 / n_buses_l]
    lst_limits_l = max_total_power_l * lst_limits_coeffs_l

    limits_l = rand(Set(lst_limits_l), n_branches_l)
    data_generator_p.branch_limits_ = Dict(zip(branches_l, limits_l))

    return data_generator_p.branch_limits_
end

#================================
    main generation function
================================#

function create_instance!(data_generator_p::RandomDataGenerator, n_scenarios_p::Int64,
                        n_limits_p::Int=1, sigma_load_p::Number=0.05, mu_load_p::Number=0.)
    reset!(data_generator_p)

    create_scenarios!(data_generator_p, n_scenarios_p)
    create_load!(data_generator_p, sigma_load_p, mu_load_p)
    create_limitable_uncertainties!(data_generator_p)
    create_imposable_uncertainties!(data_generator_p)

    for limit_count_i in 1:n_limits_p
        reset_limits!(data_generator_p)
        create_limits!(data_generator_p)

        instance_name = @sprintf("random_si%.5f_mu%.5f_%dS_l%d_%05d", sigma_load_p, mu_load_p, n_scenarios_p, limit_count_i, rand(0:99999))
        instance_path = rstrip(data_generator_p.basedata_path_, '/')*"_"*instance_name
        println("writing ", instance_path)
        write_instance(data_generator_p, instance_path)
    end
end

#======================================================
        main
======================================================#

basedata_folder = "data/random_generation/5buses/base"
basedata_path = joinpath(root_path, basedata_folder);

data_generator = RandomDataGenerator(basedata_path)

create_instance!(data_generator, 5)

@show(data_generator)

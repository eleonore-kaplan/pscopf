module DataGenerator
    import Dates
    import Distributions
    import Random
    import Statistics
    using Printf;

    #======================================================
        Includes
    ======================================================#
    include("AmplTxt.jl"); # need split_with_space
    include("Workflow.jl"); # need only reading functions

    #======================================================
            Constants
    ======================================================#

    DATEFORMAT_g = Dates.DateFormat("Y-m-dTH:M:S");


    #======================================================
            Definitions
    ======================================================#

    mutable struct RandomDataGenerator
        basedata_path_::String;
        first_ts::Dates.DateTime;
        units_data_::Dict{String, Vector{Float64}};
        units_types_data_::Dict{String, Vector{String}};
        ptdf_data_::Dict{Tuple{String, String}, Float64};
        #gen => value
        base_values_data_::Dict{String, Float64};
        #gen => maxP, sigma, mu
        uncertain_properties_::Dict{String, Vector{Float64}};

        #gen,ts,ech,s => value
        created_uncertainties_::Dict{Tuple{String, Dates.DateTime, Dates.DateTime, String}, Float64};
        branch_limits_::Dict{String, Float64};
        lst_scenarios_::Vector{String};
        lst_horizons_::Vector{Dates.DateTime};
        lst_timesteps_::Vector{Dates.DateTime};

    end

    function RandomDataGenerator(basedata_path_p::String)
        ts_l, base_values_data_l = read_base_values(basedata_path_p)

        return RandomDataGenerator(basedata_path_p,
                                ts_l,
                                Workflow.read_units(basedata_path_p),
                                Workflow.read_gen_type_bus(basedata_path_p),
                                Workflow.read_ptdf(basedata_path_p),
                                base_values_data_l,
                                read_uncertain_properties(basedata_path_p),
                                Dict{Tuple{String, Dates.DateTime, Dates.DateTime, String}, Float64}(),
                                Dict{String, Float64}(),
                                Vector{String}(),
                                Vector{Dates.DateTime}(),
                                [ts_l]
                                )
    end

    function reset_limits!(data_generator_p::RandomDataGenerator)
        data_generator_p.branch_limits_ = Dict{String, Float64}()

        return data_generator_p
    end

    function reset!(data_generator_p::RandomDataGenerator)
        data_generator_p.created_uncertainties_ = Dict{Tuple{String, Dates.DateTime, Dates.DateTime, String}, Float64}()
        data_generator_p.lst_scenarios_ = Vector{String}()
        data_generator_p.lst_horizons_ = Vector{String}()
        reset_limits!(data_generator_p)

        return data_generator_p
    end

    #================
    Reading functions
    ================#

    function read_uncertain_properties(dir_path_p::String)
        result_l = Dict{String,Vector{Float64}}();
        file_path_l = joinpath(dir_path_p, "uncertain_properties.txt");
        open(file_path_l) do file
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

    function read_base_values(dir_path_p::String)
        TS_l = Set{Dates.DateTime}()
        result_l = Dict{String,Float64}();
        file_path_l = joinpath(dir_path_p, "base_values.txt");
        open(file_path_l) do file_l
            for ln in eachline(file_l)
                # don't read commentted line
                if ln[1] != '#'
                    buffer_l = AmplTxt.split_with_space(ln);
                    result_l[buffer_l[1]] = parse(Float64, buffer_l[3])
                    push!(TS_l, Dates.DateTime(buffer_l[2] ,DATEFORMAT_g))
                end
            end
        end
        if length(TS_l) != 1
            error("base values file should indicate a single timestep : "*file_path_l)
        end
        ts_l = first(TS_l)

        return ts_l, result_l
    end

    #================
    Writing functions
    ================#
    function copy_file(from_dir_p::String, to_dir_p::String, filename_p::String; force_p::Bool=false)
        from_filepath_l = joinpath(from_dir_p, filename_p)
        to_filepath_l = joinpath(to_dir_p, filename_p)
        cp(from_filepath_l, to_filepath_l, force=force_p)
    end

    function copy_ready_pscopf_files(basedata_path_p::String, instance_path_p::String)
        limits_filename_l = "pscopf_limits.txt"
        origin_limits_filepath_l = joinpath(basedata_path_p, limits_filename_l)
        if isfile(origin_limits_filepath_l)
            copy_file(basedata_path_p, instance_path_p, limits_filename_l, force_p=true)
        end

        files_to_copy = ["pscopf_units.txt", "pscopf_ptdf.txt", "pscopf_gen_type_bus.txt"]
        for filename_l in files_to_copy
            copy_file(basedata_path_p, instance_path_p, filename_l, force_p=true)
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


    function write_pscopf_previsions(output_file_p, data_generator_p::RandomDataGenerator)
        write_pscopf_previsions(output_file_p, data_generator_p.base_values_data_, data_generator_p.lst_timesteps_, data_generator_p.lst_horizons_[1])
    end
    function write_pscopf_previsions(output_file_path, base_values_data_p, lst_timesteps_p, first_horizon_p::Dates.DateTime)
        open(output_file_path, "w") do file_l
            write(file_l, @sprintf("#%-9s%25s%25s%10s\n", "id", "h_15m", "ech", "v"))
            ech_l = first_horizon_p
            for ts_l in lst_timesteps_p
                for (gen_l,value_l) in base_values_data_p
                    write(file_l, @sprintf("%-10s%25s%25s%10.3f\n", gen_l, ts_l, ech_l,  value_l))
                end
            end
        end
    end

    function write_instance(data_generator_p::RandomDataGenerator, instance_path_p::String)
        mkpath(instance_path_p)

        copy_ready_pscopf_files(data_generator_p.basedata_path_, instance_path_p)

        output_l=joinpath(instance_path_p, "pscopf_previsions.txt")
        write_pscopf_previsions(output_l, data_generator_p)

        output_l=joinpath(instance_path_p, "pscopf_uncertainties.txt")
        write_pscopf_uncertainties(output_l, data_generator_p)

        if do_create_limits(data_generator_p)
            output_l=joinpath(instance_path_p, "pscopf_limits.txt")
            write_pscopf_limits(output_l, data_generator_p)
        end
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
        return get_buses(data_generator_p.ptdf_data_)
    end
    function get_buses(ptdf_data_p)
        return unique([bus_i for ((_,bus_i),_) in ptdf_data_p])
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
        total_base_consumption_l = 0
        for (_,base_val_l) in filter( x -> is_unit(x[1], units_types_data_p) , base_values_data_p)
            total_base_consumption_l += base_val_l
        end

        return total_base_consumption_l
    end

    function get_limitable_base_values(data_generator_p::RandomDataGenerator)
        return filter( x -> is_unit_limitable(x[1], data_generator_p) , data_generator_p.base_values_data_)
    end
    function get_imposable_base_values(data_generator_p::RandomDataGenerator)
        return filter( x -> is_unit_imposable(x[1], data_generator_p) , data_generator_p.base_values_data_)
    end

    function get_dmo_list(data_generator_p::RandomDataGenerator)
        return get_dmo_list(data_generator_p.units_data_)
    end
    function get_dmo_list(units_data_p::Dict{String, Vector{Float64}};)
        dmo_list_l = Vector{Dates.Minute}()
        for (_,gen_data_l) in units_data_p
            push!(dmo_list_l, Dates.Minute(Dates.Second(gen_data_l[5])))
        end
        return dmo_list_l
    end

    #================================
    Instance creation functions
    ================================#

    function create_scenarios!(data_generator_p::RandomDataGenerator, n_scenarios_p::Int64)
        data_generator_p.lst_scenarios_ = [@sprintf("S%d", x) for x in 1:n_scenarios_p];
        return data_generator_p.lst_scenarios_
    end

    function create_horizons!(data_generator_p::RandomDataGenerator, lst_delta_for_horizons_p::Vector{Dates.Minute})
        lst_deltas_l = sort(unique(lst_delta_for_horizons_p), rev=true)
        lst_horizons_l = []
        for delta_l in lst_deltas_l
            ech_l = data_generator_p.first_ts - delta_l
            push!(lst_horizons_l, ech_l)
        end

        data_generator_p.lst_horizons_ = lst_horizons_l
        return data_generator_p.lst_horizons_
    end

    function create_load!(data_generator_p::RandomDataGenerator,
                        sigma_load_p::Number=0.05,
                        mu_load_p::Number=0.,
                        different_per_scenario_p::Bool=true,
                        buses_coeffs_p=nothing)

        n_scenarios_l = length(data_generator_p.lst_scenarios_)
        total_base_consumption_l = get_total_base_consumption(data_generator_p)

        # suppose buses coeffs do not change with time
        buses_l = get_buses(data_generator_p)
        buses_coeffs_l = buses_coeffs_p
        if ( !isnothing(buses_coeffs_l) &&
            ( sort(collect(keys(buses_coeffs_l))) != sort(buses_l)) )
            error("wrong input buses coeffs. buses names or number do not correspond:\n $(sort(collect(keys(buses_coeffs_l)))) \n vs $(sort(buses_l))")
        end
        if isnothing(buses_coeffs_l)
            coeffs_l = rand(length(buses_l))
            coeffs_l = coeffs_l / sum(coeffs_l)
            buses_coeffs_l = Dict(zip(buses_l,coeffs_l))
        else
            #normalize coeffs
            sum_l = sum([coeff_l for (_,coeff_l) in buses_coeffs_l])
            for (bus_l,coeff_l) in buses_coeffs_l
                buses_coeffs_l[bus_l] = coeff_l / sum_l
            end
        end
        println("buses_coeffs_l : $buses_coeffs_l")

        # Create random total loads (ts,ech,s)
        random_total_consumption_l = Dict{Tuple{Dates.DateTime, Dates.DateTime, String}, Float64}()
        for ts_l in data_generator_p.lst_timesteps_
            for ech_l in data_generator_p.lst_horizons_
                factor_l = max(Dates.value(floor(ts_l - ech_l, Dates.Minute)) / 60 + 15/60, 0) #+15/60 to add noise even for ech=ts
                adjusted_sigma_load_l = factor_l * sigma_load_p
                if different_per_scenario_p
                    rand_deviations_l = rand(Distributions.Normal(mu_load_p, adjusted_sigma_load_l), n_scenarios_l);
                else
                    deviation_l = rand(Distributions.Normal(mu_load_p, adjusted_sigma_load_l))
                    rand_deviations_l = fill(deviation_l, n_scenarios_l);
                end
                for scenario_index_l in 1:n_scenarios_l
                    random_value_l = total_base_consumption_l * (1 + rand_deviations_l[scenario_index_l])
                    random_total_consumption_l[ts_l, ech_l, data_generator_p.lst_scenarios_[scenario_index_l]] = max(random_value_l, 0)
                end
            end
        end

        # distribute the total random consumption on buses
        for ((ts_l, ech_l, scenario_l), total_load_l) in random_total_consumption_l
            for (bus_l,coeff_l) in buses_coeffs_l
                data_generator_p.created_uncertainties_[bus_l,ts_l,ech_l,scenario_l] = coeff_l * total_load_l
            end
        end

        return data_generator_p.created_uncertainties_
    end

    function create_prod_uncertainties!(data_generator_p::RandomDataGenerator)
        n_scenarios_l = length(data_generator_p.lst_scenarios_)

        for ts_l in data_generator_p.lst_timesteps_
            for ech_l in data_generator_p.lst_horizons_
                for (gen_l,base_value_l) in data_generator_p.base_values_data_
                    p_max_l = data_generator_p.uncertain_properties_[gen_l][1]

                    sigma_l = data_generator_p.uncertain_properties_[gen_l][2]
                    mu_l = data_generator_p.uncertain_properties_[gen_l][3]
                    factor_l = max(Dates.value(floor(ts_l - ech_l, Dates.Minute)) / 60  + 15/60, 0) #+15/60 to add noise even for ech=ts
                    adjusted_sigma_l = factor_l * sigma_l
                    adjusted_mu_l = factor_l * mu_l

                    #@printf("generate production levels for unit %s at horizon %s with parameters σ'=%f and μ'=%f .\n", gen_l, ech_l, adjusted_sigma_l, adjusted_mu_l)
                    rand_deviations = rand(Distributions.Normal(adjusted_mu_l, adjusted_sigma_l), n_scenarios_l);
                    for scenario_index_l in 1:n_scenarios_l
                        rand_value_l = base_value_l + rand_deviations[scenario_index_l] * p_max_l
                        rand_value_l = min(rand_value_l, p_max_l)
                        rand_value_l = max(rand_value_l, 0)
                        data_generator_p.created_uncertainties_[gen_l,ts_l,ech_l,data_generator_p.lst_scenarios_[scenario_index_l]] = rand_value_l
                    end
                end
            end
        end

        return data_generator_p.created_uncertainties_
    end

    function create_limits!(data_generator_p::RandomDataGenerator)
        total_base_consumption_l = get_total_base_consumption(data_generator_p)

        branches_l = get_branches(data_generator_p)
        n_branches_l = length(branches_l)
        n_buses_l = length(get_buses(data_generator_p))
        lst_limits_coeffs_l = [1, 1/n_branches_l, 0.5 * 1 / n_branches_l, 2 * 1 / n_branches_l, 1 / n_buses_l]
        lst_limits_l = total_base_consumption_l * lst_limits_coeffs_l

        limits_l = rand(Set(lst_limits_l), n_branches_l)
        data_generator_p.branch_limits_ = Dict(zip(branches_l, limits_l))

        return data_generator_p.branch_limits_
    end

    function do_create_limits(data_generator_p::RandomDataGenerator)
        filepath_l = joinpath(data_generator_p.basedata_path_, "pscopf_limits.txt")
        return !isfile(filepath_l)
    end

    #================================
        main generation function
    ================================#

    function create_instance!(data_generator_p::RandomDataGenerator,
                            n_scenarios_p::Int64, lst_delta_for_horizons_p::Vector{Dates.Minute};
                            sigma_load_p::Number=0.05, mu_load_p::Number=0., different_load_per_scenario_p::Bool=true, buses_coeffs_p::Union{Nothing,Dict{String,Float64}}=nothing,
                            instance_name_p::String="")
        @printf("Generate instance from base folder %s .\n", data_generator_p.basedata_path_)
        reset!(data_generator_p)

        @printf("generate %d scenarios.\n", n_scenarios_p)
        create_scenarios!(data_generator_p, n_scenarios_p)
        create_horizons!(data_generator_p, lst_delta_for_horizons_p)
        println("Considered horizon dates : ", data_generator_p.lst_horizons_)
        @printf("generate random loads with base parameters σ=%f and μ=%f .\n", sigma_load_p, mu_load_p)
        create_load!(data_generator_p, sigma_load_p, mu_load_p, different_load_per_scenario_p, buses_coeffs_p)
        println("generate random uncertainties.")
        create_prod_uncertainties!(data_generator_p)
        if do_create_limits(data_generator_p)
            println("generate random branch limits.")
            create_limits!(data_generator_p)
        end

        instance_name = ( length(instance_name_p) > 0 ? instance_name_p
                            : @sprintf("random_si%.5f_mu%.5f_%dS_%05d", sigma_load_p, mu_load_p, n_scenarios_p, rand(0:99999))
                    )
        instance_path = rstrip(data_generator_p.basedata_path_, '/')*"_"*instance_name
        println("writing the generated instance to ", instance_path)
        write_instance(data_generator_p, instance_path)

        return instance_path
    end

end #Module DataGenerator

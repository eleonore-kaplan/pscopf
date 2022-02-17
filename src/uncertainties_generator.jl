using Distributions
using Dates

using ..Networks

struct UncertaintiesGenerator <: AbstractDataGenerator
    network::Networks.Network
    target_timepoints::Vector{Dates.DateTime}
    horizon_timepoints::Vector{Dates.DateTime}
    #potentially split into load_uncertainties_distribution and unit_uncertainties_distribution :
    uncertainties_distribution #ditribution info for each limitable unit and load
    nb_scenarios::Int
end

function scenario_name(index_scenario::Int)
    return "S"*string(index_scenario)
end

function generate_uncertainties(network::Networks.Network, target_timepoints::Vector{Dates.DateTime}, horizon_timepoints::Vector{Dates.DateTime},
    uncertainties_distribution, nb_scenarios::Int)
    generator = UncertaintiesGenerator(network, target_timepoints, horizon_timepoints, uncertainties_distribution, nb_scenarios)
    return launch(generator)
end

function launch(uncertainties_generator::UncertaintiesGenerator)
    uncertainties = Uncertainties()

    scenarios = scenario_name.(1:uncertainties_generator.nb_scenarios)

    for ech in uncertainties_generator.horizon_timepoints
        for bus_or_gen in keys(uncertainties_generator.uncertainties_distribution)
            uncertain_distro = uncertainties_generator.uncertainties_distribution[bus_or_gen]
            nodal_injection_name = Networks.get_id(bus_or_gen)
            for ts in uncertainties_generator.target_timepoints
                values = generate_values(uncertain_distro, ech, ts, uncertainties_generator.nb_scenarios)
                for (scenario_name,val) in zip(scenarios,values)
                    add_uncertainty!(uncertainties, ech, nodal_injection_name, ts, scenario_name, val)
                end
            end
        end
    end

    return uncertainties
end

function generate_values(uncertain_distro::UncertaintyDistribution,
                        ech::Dates.DateTime, ts::Dates.DateTime,
                        nb_scenarios::Int64)

    delta_time_l = max(0,
                    Dates.value(floor(ts - ech, Dates.Second)) / 3600)
    factor_l = (delta_time_l * uncertain_distro.time_factor) ^ uncertain_distro.cone_effect
    adjusted_sigma_l = factor_l * uncertain_distro.sigma
    rand_deviations_l = rand(Distributions.Normal(0., adjusted_sigma_l), nb_scenarios)
    random_values_l = uncertain_distro.mu * (1 .+ rand_deviations_l)
    values_l = max.(uncertain_distro.min_value, random_values_l)
    values_l = min.(uncertain_distro.max_value, values_l)

    return values_l
end

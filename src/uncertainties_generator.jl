#TODO

struct UncertaintiesGenerator <: AbstractDataGenerator
    grid::AbstractGrid
    target_timepoints::Vector{Dates.DateTime}
    horizon_timepoints::Vector{Dates.DateTime}
    #potentially split into load_uncertainties_distribution and unit_uncertainties_distribution :
    uncertainties_distribution #ditribution info for each limitable unit and load
    nb_scenarios::Int
end

function scenario_name(index_scenario::Int)
    return "S"*string(index_scenario)
end

function generate_uncertainties(grid::AbstractGrid, target_timepoints::Vector{Dates.DateTime}, horizon_timepoints::Vector{Dates.DateTime},
    uncertainties_distribution, nb_scenarios::Int)
    generator = UncertaintiesGenerator(grid, target_timepoints, horizon_timepoints, uncertainties_distribution, nb_scenarios)
    #FIXME add write to file
    return launch(generator)
end

function launch(uncertainties_generator::UncertaintiesGenerator)
    uncertainties = Uncertainties()

    scenarios = scenario_name.(1:uncertainties_generator.nb_scenarios)

    for ech in uncertainties_generator.horizon_timepoints
        for nodal_injection_name in keys(uncertainties_distribution)
            for ts in uncertainties_generator.target_timepoints
                values = generate_values()
                for (scenario_name,val) in zip(scenarios,values)
                    # error("unimplemented")
                    #TODO: generate and add uncertainties[ech][nodal_injection_name][ts][scenario_name]
                    add_uncertainty!(uncertainties, ech, nodal_injection_name, ts, scenario_name, val)
                end
            end
        end
    end

    return uncertainties
end

function generate_values()

end
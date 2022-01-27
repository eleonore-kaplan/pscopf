
struct EchGenerator <: AbstractLaunchable
    grid::Grid
    target_timepoints::Vector{Dates.DateTime}
    management_mode::ManagementMode
end

"""
    generate_ech

generates the horizon timepoints for a given management mode.

# Arguments
    - `grid::Grid` : description of the electric grid
    - `target_timepoints::Vector{Dates.DateTime}` : vector of the target timepoints to consider 
    - `management_mode::ManagementMode` : the management mode for which the horizon points will be generated
"""
function generate_ech(grid::Grid, target_timepoints::Vector{Dates.DateTime}, management_mode::ManagementMode)
    sorted_target_timepoints = sort(target_timepoints)
    generator = EchGenerator(grid, sorted_target_timepoints, management_mode)
    return launch(generator)
end

function launch(ech_generator::EchGenerator)
    deltas = [Dates.Hour(4), Dates.Hour(1), Dates.Minute(30), Dates.Minute(15), Dates.Minute(0)]

    if ech_generator.management_mode == PSCOPF_MODE_1
        return generate_with_deltas(ech_generator, deltas)
    
    elseif ech_generator.management_mode == PSCOPF_MODE_2
        return generate_with_deltas(ech_generator, deltas)

    elseif ech_generator.management_mode == PSCOPF_MODE_3
        return generate_with_deltas(ech_generator, deltas)
    end 
    error("unsuppported mode : ", ech_generator.management_mode)
end

function generate_with_deltas(ech_generator::EchGenerator, deltas)
    ts1 = ech_generator.target_timepoints[1]
    return ts1 .- deltas
end


struct EchGenerator
    grid::Grid
    target_timepoints::Vector{Dates.DateTime}
    management_mode::ManagementMode

    horizon_timepoints::Vector{Dates.DateTime}
end
function EchGenerator(grid::Grid, target_timepoints::Vector{Dates.DateTime}, management_mode::ManagementMode)
    return EchGenerator(grid, target_timepoints, management_mode, Vector{Dates.DateTime}())
end

function launch!(ech_generator::EchGenerator)
    ech_generator.horizon_timepoints = launch(ech_generator)
    return ech_generator.horizon_timepoints
end

##########################################################################################################
#                            PARTIE IMPORTANTE :
##########################################################################################################
function generate_ech(grid::Grid, target_timepoints::Vector{Dates.DateTime}, management_mode::ManagementMode)
    generator = EchGenerator(grid, target_timepoints, management_mode)
    return launch(generator)
end

function launch(ech_generator::EchGenerator)
    if ech_generator.management_mode == PSCOPF_MODE_1
        ts1 = ech_generator.target_timepoints[1]
        deltas = [Dates.Hour(4), Dates.Hour(1), Dates.Minute(30), Dates.Minute(15), Dates.Minute(0)]
        return ts1 .- deltas
    
    elseif ech_generator.management_mode == PSCOPF_MODE_2
        error("unimplemented")
    elseif ech_generator.management_mode == PSCOPF_MODE_3
        error("unimplemented")
    end 
    error("unsuppported mode : ", ech_generator.management_mode)
end

##########################################################################################################
##########################################################################################################

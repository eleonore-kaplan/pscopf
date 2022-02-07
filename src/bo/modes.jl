using Dates

struct ManagementMode
    name::String
    fo_length::Dates.Minute
end

function get_fo_length(mode::ManagementMode)
    return mode.fo_length
end

PSCOPF_MODE_1 = ManagementMode("mode_1", Dates.Minute(60))
PSCOPF_MODE_2 = ManagementMode("mode_2", Dates.Minute(60))
PSCOPF_MODE_3 = ManagementMode("mode_3", Dates.Minute(60))

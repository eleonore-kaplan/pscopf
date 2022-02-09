include("PSCOPF.jl")

using Dates

using .PSCOPF

# load network
data_path = joinpath(@__DIR__, "..", "2buses")
network = PSCOPF.Data.pscopfdata2network(data_path)

created_instance_path = joinpath(data_path, "copied")

PSCOPF.PSCOPFio.write(created_instance_path, network)

# Generate uncertainties
uncertainties_distribution = PSCOPF.PSCOPFio.read_uncertainties_distributions(network, data_path)
nb_scenarios = 5

ts1 = Dates.DateTime("2015-01-01T11:00:00")
TS = PSCOPF.create_target_timepoints(ts1)
ECHs = []
for mode in [PSCOPF.PSCOPF_MODE_1, PSCOPF.PSCOPF_MODE_2, PSCOPF.PSCOPF_MODE_3]
    push!(ECHs, PSCOPF.generate_ech(network, TS, mode) )
end
horizon_timepoints = sort(unique(Iterators.flatten(ECHs)))

uncertainties = PSCOPF.generate_uncertainties(network, TS, horizon_timepoints,
                                            uncertainties_distribution, nb_scenarios)

PSCOPF.PSCOPFio.write(created_instance_path, uncertainties)


# Launch mode 1
mode = PSCOPF.PSCOPF_MODE_1

network = PSCOPF.Data.pscopfdata2network(created_instance_path)
un = PSCOPF.PSCOPFio.read_uncertainties(created_instance_path)
ts1 = Dates.DateTime("2015-01-01T11:00:00")
TS = PSCOPF.create_target_timepoints(ts1)
ECH = PSCOPF.generate_ech(network, TS, mode)

sequence = PSCOPF.generate_sequence(network, TS, ECH, mode)
exec_context = PSCOPF.PSCOPFContext(network, TS, mode)
PSCOPF.add_schedule!(exec_context, PSCOPF.Schedule(PSCOPF.Market(), ECH[1]))
PSCOPF.add_schedule!(exec_context, PSCOPF.Schedule(PSCOPF.TSO(), ECH[1]))
PSCOPF.run!(exec_context, sequence)

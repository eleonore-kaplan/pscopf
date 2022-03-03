using Dates

root_path = dirname(@__DIR__)
push!(LOAD_PATH, root_path);
cd(root_path)
include(joinpath(root_path, "src", "PSCOPF.jl"));

# load network
data_path = joinpath(@__DIR__, "..", "data", "2buses_usecase")
network = PSCOPF.Data.pscopfdata2network(data_path)

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

# write/rewrite instance files
created_instance_path = joinpath(data_path, "instance")
rm(created_instance_path, recursive=true, force=true)
PSCOPF.PSCOPFio.write(created_instance_path, network)
PSCOPF.PSCOPFio.write(created_instance_path, uncertainties)
cp(joinpath(data_path, "pscopf_init.txt"), joinpath(created_instance_path, "pscopf_init.txt"), force=true)

# Launch mode 1
mode = PSCOPF.PSCOPF_MODE_1

network = PSCOPF.Data.pscopfdata2network(created_instance_path)
uncerts = PSCOPF.PSCOPFio.read_uncertainties(created_instance_path)
gen_init_state = PSCOPF.PSCOPFio.read_initial_state(created_instance_path)
println("init_state: ", gen_init_state)


ts1 = Dates.DateTime("2015-01-01T11:00:00")
TS = PSCOPF.create_target_timepoints(ts1) #11h, 11h15, 11h30, 11h45
ECH = PSCOPF.generate_ech(network, TS, mode)

sequence = PSCOPF.generate_sequence(network, TS, ECH, mode)

PSCOPF.rm_non_prefixed(created_instance_path, "pscopf_")
exec_context = PSCOPF.PSCOPFContext(network, TS, mode, gen_init_state, uncerts, nothing, created_instance_path)

PSCOPF.run!(exec_context, sequence)

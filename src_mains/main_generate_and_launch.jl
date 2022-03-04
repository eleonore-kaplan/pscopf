using Dates

root_path = dirname(@__DIR__)
push!(LOAD_PATH, root_path);
cd(root_path)
include(joinpath(root_path, "src", "PSCOPF.jl"));




#########################
# INPUT & PARAMS
#########################

# data_path is the path to the input data directory containing :
# pscopf_units : the description of the units
# pscopf_init : the description of the initial state of units (just before the first interest timepoit T)
# pscopf_limits : the flow capacity of each branch
# pscopf_ptdf : the ptdf coefficients per (branch, bus_id)
# uncertainties_distribution : distribution parameters used to generate injections uncertainties
data_path = ( length(ARGS) > 0 ? ARGS[1] :
                joinpath(@__DIR__, "..", "data", "2buses_usecase") )

# instance_and_out_path is the path that will contain the full instance data :
# pscopf_uncertainties : the randomly generated nodal injections
# pscopf_units : copied from the input data_path
# pscopf_init : copied from the input data_path
# pscopf_limits : copied from the input data_path
# pscopf_ptdf : copied from the input data_path
instance_and_out_path = ( length(ARGS) > 1 ? ARGS[2] :
                            joinpath(data_path, "instance") )


# Number of scenarios to be generated
nb_scenarios = ( length(ARGS) > 2 ? parse(Int, ARGS[3]) : 5)

ts1 = Dates.DateTime("2015-01-01T11:00:00")
TS = PSCOPF.create_target_timepoints(ts1) #T: 11h, 11h15, 11h30, 11h45




#########################
# EXECUTION
#########################

# load network
network = PSCOPF.Data.pscopfdata2network(data_path)


# Generate uncertainties
uncertainties_distribution = PSCOPF.PSCOPFio.read_uncertainties_distributions(network, data_path)

ECHs = []
for mode in [PSCOPF.PSCOPF_MODE_1, PSCOPF.PSCOPF_MODE_2, PSCOPF.PSCOPF_MODE_3]
    push!(ECHs, PSCOPF.generate_ech(network, TS, mode) )
end
horizon_timepoints = sort(unique(Iterators.flatten(ECHs)))

uncertainties = PSCOPF.generate_uncertainties(network, TS, horizon_timepoints,
                                            uncertainties_distribution, nb_scenarios)


# write/rewrite instance files
rm(instance_and_out_path, recursive=true, force=true)
PSCOPF.PSCOPFio.write(instance_and_out_path, network)
PSCOPF.PSCOPFio.write(instance_and_out_path, uncertainties)
cp(joinpath(data_path, "pscopf_init.txt"), joinpath(instance_and_out_path, "pscopf_init.txt"), force=true)


# Launch mode 1
mode = PSCOPF.PSCOPF_MODE_1

network = PSCOPF.Data.pscopfdata2network(instance_and_out_path)
uncertainties = PSCOPF.PSCOPFio.read_uncertainties(instance_and_out_path)
gen_init_state = PSCOPF.PSCOPFio.read_initial_state(instance_and_out_path)
println("init_state: ", gen_init_state)

ECH = PSCOPF.generate_ech(network, TS, mode)

sequence = PSCOPF.generate_sequence(network, TS, ECH, mode)

PSCOPF.rm_non_prefixed(instance_and_out_path, "pscopf_")
exec_context = PSCOPF.PSCOPFContext(network, TS, mode, gen_init_state,
                                    uncertainties, nothing,
                                    instance_and_out_path)

PSCOPF.run!(exec_context, sequence)

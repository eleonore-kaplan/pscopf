root_path = raw"D:\AppliRTE\repo\scopf-quanti"
push!(LOAD_PATH, root_path);
cd(root_path);
include(joinpath(root_path, "AmplTxt.jl"));
include(joinpath(root_path, "ProductionUnits.jl"));
include(joinpath(root_path, "Workflow.jl"));

test_name = "5buses"
dir_path = joinpath(root_path, test_name);

# read the itools ampl-txt files
# read uncertainties
# read production units data
# compute PTDF: export text (scenario, ts, ech, state, bus, branch) --> PTDF value
launcher = Workflow.Launcher(dir_path)
##################
## market simulation
##################
# init_program = Workflow.get_market(launcher)
# # an optimization problem for (scenario, ts, ech)
# # common : production units constraints
# # input : EnR uncertainties
# # input/output : the production program of each groups for (scenario, ts, ech)
# market_program = Workflow.apply_market(launcher, init_program)

##################
## scopf
##################
# inputs
# - for (scenario, ts, ech) the new planning
# - for (scenario, ts, ech) the network and its constraints
# - available preventive or currative actions

# a unique optimization problem
# coupling variables : preventive actions (thermal or EnR)
# for (scenario, ts, ech) 

# inputs
# - preventive actions
# - costs
# - overflow etc.


##################
## real market simulation
##################
# input : 
# - EnR uncertainties for the realization
# - preventive actions
# an optimization problem for ONE of (scenario, ts, ech)
# - optimal redispatch 
# - optimal network maximization


root_path = raw"D:\AppliRTE\repo\scopf-quanti"
push!(LOAD_PATH, root_path);
cd(root_path);
include(joinpath(root_path, "AmplTxt.jl"));
include(joinpath(root_path, "Workflow.jl"));

test_name = "5buses_wind"
dir_path = joinpath(root_path, test_name);

launcher = Workflow.Launcher(dir_path);

ech=DateTime("2015-01-01T09:00:00")
K_IMPOSABLE = Workflow.K_IMPOSABLE;
K_LIMITABLE = Workflow.K_LIMITABLE;
model, p_lim, p_imposable= Workflow.sc_opf(launcher, ech);



# using Clp;

# # set_optimizer(model, Xpress.Optimizer);
# set_optimizer(model, Clp.Optimizer);

# optimize!(model);


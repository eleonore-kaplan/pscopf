

using Dates: Date, DateTime;

root_path = raw"D:\AppliRTE\repo\scopf-quanti";
push!(LOAD_PATH, root_path);
cd(root_path);
include(joinpath(root_path, "AmplTxt.jl"));
include(joinpath(root_path, "Workflow.jl"));

test_name = "5buses_wind";
dir_path = joinpath(root_path, test_name);

launcher = Workflow.Launcher(dir_path);

ech = DateTime("2015-01-01T09:00:00");

launcher.NO_LIMITABLE = false;
launcher.NO_IMPOSABLE = false;
launcher.NO_LIMITATION = false;
p_res = 0;
p_res_min = -p_res;
p_res_max = p_res;
model, p_lim, p_imposable = Workflow.sc_opf(launcher, ech, p_res_min, p_res_max);



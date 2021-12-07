

using Dates: Date, DateTime;


#root_path = raw"D:\AppliRTE\repo\scopf-quanti";
root_path = @__DIR__;
push!(LOAD_PATH, root_path);
cd(root_path);
include(joinpath(root_path, "AmplTxt.jl"));
include(joinpath(root_path, "Workflow.jl"));


test_name = length(ARGS) > 0 ? ARGS[1] : "5buses_wind";
println("test case : ", test_name)
dir_path = joinpath(root_path, test_name);

launcher = Workflow.Launcher(dir_path);

ech = length(ARGS) > 1 ? DateTime(ARGS[2]) : DateTime("2015-01-01T09:00:00");
# ech = DateTime("2015-01-01T09:00:00");
# ech = DateTime("2015-01-01T11:00:00"); #test
println("ech : ", ech)

launcher.NO_LIMITABLE = false;
launcher.NO_IMPOSABLE = false;
launcher.NO_LIMITATION = false;
p_res = 100;
p_res_min = -p_res;
p_res_max = p_res;
model, p_lim, p_imposable = Workflow.sc_opf(launcher, ech, p_res_min, p_res_max);

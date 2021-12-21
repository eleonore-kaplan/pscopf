

using Dates: Date, DateTime;


#root_path = raw"D:\AppliRTE\repo\scopf-quanti";
root_path = @__DIR__;
push!(LOAD_PATH, root_path);
cd(root_path);
include(joinpath(root_path, "AmplTxt.jl"));
include(joinpath(root_path, "Workflow.jl"));


test_name = length(ARGS) > 0 ? ARGS[1] : "data/dmo/2buses/mix";
println("test case : ", test_name)
dir_path = joinpath(root_path, test_name);

launcher = Workflow.Launcher(dir_path, joinpath(dir_path, "with_dmo"));

ech = length(ARGS) > 1 ? DateTime(ARGS[2]) : DateTime("2015-01-01T09:00:00");
println("ech : ", ech)

launcher.NO_LIMITABLE = false;
launcher.NO_IMPOSABLE = false;
launcher.NO_LIMITATION = false;
launcher.NO_DMO = false;
p_res = 0;
p_res_min = -p_res;
p_res_max = p_res;

Workflow.run(launcher, [ech], p_res_min, p_res_max);

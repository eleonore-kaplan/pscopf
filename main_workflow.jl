

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
launcher.NO_DMO = true; #If true (non-default), will act as if ( TS - DMO(unit) = ECH ) for all imposable units
launcher.NO_EOD_SLACK = true; #If true (non-default), will not introduce infeasibility slacks for the EOD
launcher.NO_BRANCH_SLACK = true; #If true (non-default), will not introduce infeasibility slacks for the flow limits
p_res = 250;
p_res_min = -p_res;
p_res_max = p_res;
Workflow.sc_opf(launcher, ech, p_res_min, p_res_max);

# Workflow.worse_case(launcher, ech);

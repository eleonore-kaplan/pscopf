

using Dates: Date, DateTime;


#root_path = raw"D:\AppliRTE\repo\scopf-quanti";
root_path = @__DIR__;
push!(LOAD_PATH, root_path);
cd(root_path);
include(joinpath(root_path, "scopf_utils.jl"));
include(joinpath(root_path, "AmplTxt.jl"));
include(joinpath(root_path, "Workflow.jl"));


test_name = length(ARGS) > 0 ? ARGS[1] : "data/dmo/2buses/2ech";
println("test case : ", test_name)
dir_path = joinpath(root_path, test_name);

launcher = Workflow.Launcher(dir_path);
SCOPFutils.init_logging(launcher.dirpath)

launcher.NO_LIMITABLE = false;
launcher.NO_IMPOSABLE = false;
launcher.NO_LIMITATION = false;
launcher.NO_DMO = false; #If true (non-default), will act as if ( TS - DMO(unit) = ECH ) for all imposable units
launcher.NO_CUT_PRODUCTION = false; #If true (non-default), will not introduce infeasibility slacks to cut consumption
launcher.NO_CUT_CONSUMPTION = false; #If true (non-default), will not introduce infeasibility slacks to cut production
launcher.NO_BRANCH_SLACK = false; #If true (non-default), will not introduce infeasibility slacks for the flow limits
#launcher.COEFF_CUT_PROD
#launcher.COEFF_CUT_CONSO
#launcher.COEFF_BRANCH_SLACK
#launcher.SCENARIOS_FLEXIBILITY

p_res = 0;
p_res_min = -p_res;
p_res_max = p_res;
results = Workflow.run(launcher, p_res_min, p_res_max);

println(launcher.previsions)

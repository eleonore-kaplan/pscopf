import Dates

root_path = @__DIR__;
push!(LOAD_PATH, root_path);
cd(root_path);

#======================================================
    Generate use case
======================================================#
include("DataGenerator.jl")

println("-"^120)
println("Generate use case")
basedata_folder = "data/random_generation/2buses/base"
basedata_path = joinpath(root_path, basedata_folder);

data_generator = DataGenerator.RandomDataGenerator(basedata_path)

# List of horizons
# FIXME : should we remove ECH=TS ? should we add it if it's absent ?
lst_deltas_from_markets = [Dates.Minute(120), Dates.Minute(30), Dates.Minute(60)]
lst_deltas_from_dmo = DataGenerator.get_dmo_list(data_generator)
lst_delta_for_horizons = union(lst_deltas_from_markets, lst_deltas_from_dmo)

instance_path = DataGenerator.create_instance!(data_generator, 5, lst_delta_for_horizons, instance_name_p="my_instance")


#======================================================
    Launch Mode 1
======================================================#
include(joinpath(root_path, "AmplTxt.jl"));
include(joinpath(root_path, "Workflow.jl"));

println("-"^120)
println("test case : ", instance_path)
launcher = Workflow.Launcher(instance_path);

launcher.NO_LIMITABLE = false;
launcher.NO_IMPOSABLE = false;
launcher.NO_LIMITATION = false;
launcher.NO_DMO = false; #If true (non-default), will act as if ( TS - DMO(unit) = ECH ) for all imposable units
launcher.NO_EOD_SLACK = false; #If true (non-default), will not introduce infeasibility slacks for the EOD
launcher.NO_BRANCH_SLACK = false; #If true (non-default), will not introduce infeasibility slacks for the flow limits

p_res = 10;
p_res_min = -p_res;
p_res_max = p_res;

results = Workflow.run(launcher, p_res_min, p_res_max, mode_p=1);

println("-"^120)
println(results)

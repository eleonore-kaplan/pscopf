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
basedata_folder = "data/random_generation/2buses_simple/base"
#basedata_folder = "data/random_generation/2buses/base"
#basedata_folder = "data/random_generation/5buses/base"
basedata_path = joinpath(root_path, basedata_folder);

data_generator = DataGenerator.RandomDataGenerator(basedata_path)

# List of horizons
# FIXME : should we remove ECH=TS ? should we add it if it's absent ?
lst_deltas_from_markets = [Dates.Minute(120), Dates.Minute(30), Dates.Minute(60)]
lst_deltas_from_dmo = DataGenerator.get_dmo_list(data_generator)
lst_delta_for_horizons = union(lst_deltas_from_markets, lst_deltas_from_dmo)

instance_path = DataGenerator.create_instance!(data_generator, 5, lst_delta_for_horizons, instance_name_p="test")


#======================================================
    Launch Mode 1
======================================================#
include(joinpath(root_path, "scopf_utils.jl"));
include(joinpath(root_path, "AmplTxt.jl"));
include(joinpath(root_path, "Workflow.jl"));

println("-"^120)
println("test case : ", instance_path)
launcher = Workflow.Launcher(instance_path);
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

p_res = 10;
p_res_min = -p_res;
p_res_max = p_res;

#results = Workflow.run(launcher, p_res_min, p_res_max, mode_p=1);

ECH = Workflow.get_sorted_ech(launcher);

Workflow.print_config(launcher)


#####
#    Mode 1
#####

@info "Launch PSCOPF mode 1 for horizons : $(ECH)"
dict_results_l = Dict{DateTime, ModelContainer}()
clear_output_files(launcher);

for (index_l, ech_l)  in enumerate(ECH)
    @info "-"^30 * "   ECH : $ech_l   " * "-"^60

    #Balance the uncertainties for each scenario separately
    balance_scenarios_eod!(launcher, ech_l)

    #Decide on the production levels of the units based on the DMO and ech
    #Decisions can be fixed for all scenarios (limitables and DMO>=ECH) or by scenario (DMO<ECH)
    result_l = sc_opf(launcher, ech_l, p_res_min, p_res_max)
    dict_results_l[ech_l] = result_l

    #Propagate PSCOPF decisions
    #If needed, Update the production schedule to be considered in the following ech
    if index_l < length(ECH)
        @info "Update schedule for upcoming iteration : $(ECH[index_l+1])"
        update_schedule!(launcher, ECH[index_l+1], ech_l, result_l.limitable_modeler, result_l.imposable_modeler)
    end
end
write_previsions(launcher)

#####

Workflow.assessment_step(launcher, dict_results_l, p_res_min, p_res_max)


using Dates;
using Printf;
using Distributions;

# root_path = raw"D:\AppliRTE\repo\scopf-quanti";
root_path = @__DIR__;
push!(LOAD_PATH, root_path);
cd(root_path);
include(joinpath(root_path, "AmplTxt.jl"));
include(joinpath(root_path, "Workflow.jl"));
include(joinpath(root_path, "DataManager.jl"));

# test_name = "5buses_wind";
test_name = "2buses"
dir_path = joinpath(root_path, test_name);

flexibility = read_flexibility(dir_path);


N_SCENARIO = 5;
df = Dates.DateFormat("Y-m-d-H:M");
h = Dates.DateTime("2015-01-01-11:00", df);
h_1 = Dates.DateTime("2015-01-01-10:00", df);
h_2 = Dates.DateTime("2015-01-01-09:00", df);

# TIME_STEP =  [Minute(0), Minute(15), Minute(30), Minute(45)];
# TIME_STEP =  [Minute(0), Minute(15)];
TIME_STEP =  [Minute(0)];
HORIZON = [h_2, h_1, h];

SCENARIO = [@sprintf("S%d", x) for x in 1:N_SCENARIO];

println("TIME_STEP : ", TIME_STEP);
println("SCENARIO : ", SCENARIO);
println("HORIZON : ", HORIZON);


id_fuel = read_id_fuel(dir_path);
amplTxt = AmplTxt.read(test_name);
num_to_name, bus_load = read_bus_load(amplTxt);
uncertainties, pmax_uncertain = read_uncertainties(dir_path);

println(bus_load);

println(id_fuel);
println(flexibility);

output_file_path = joinpath(dir_path, "pscopf_uncertainties.txt");
write_pscopf_uncertainties(output_file_path, uncertainties, SCENARIO, HORIZON, TIME_STEP);

output_file_path = joinpath(dir_path, "pscopf_previsions.txt");
write_pscopf_previsions(output_file_path, uncertainties, SCENARIO, HORIZON, TIME_STEP);

output_file_path = joinpath(dir_path, "pscopf_units.txt");
write_pscopf_units(output_file_path, amplTxt, id_fuel, flexibility);

output_file_path = joinpath(dir_path, "pscopf_gen_type_bus.txt");
write_pscopf_gen_type_bus(output_file_path, amplTxt, id_fuel, num_to_name);

println(id_fuel);
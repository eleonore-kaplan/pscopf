root_path = raw"D:\AppliRTE\repo\scopf-quanti"
push!(LOAD_PATH, root_path);
cd(root_path);
include(joinpath(root_path, "AmplTxt.jl"));
include(joinpath(root_path, "ProductionUnits.jl"));
include(joinpath(root_path, "Workflow.jl"));

using Dates;

test_name = "5buses"
dir_path = joinpath(root_path, test_name);

# read the itools ampl-txt files
# read uncertainties
# read production units data
# compute PTDF: export text (scenario, ts, ech, state, bus, branch) --> PTDF value
launcher = Workflow.Launcher(dir_path);
df = Dates.DateFormat("yyyy-mm-dd-H:M");
dt = Dates.DateTime(2015,1,1,11,30)
ech = Dates.DateTime("2015-01-01-11:00",df)

Workflow.add_uncertainties(launcher, "name", "bus_name", ech, dt, 10)

println(launcher.uncertainties)
dt
ech
dt-ech

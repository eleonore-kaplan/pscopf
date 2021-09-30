itools_path=raw"D:\AppliRTE\repo\naza-mpc\powsybl\bin\itools"

# convert-network --input-file --output-file ampl --output-format AMPL

root_path = raw"D:\AppliRTE\repo\scopf-quanti"
push!(LOAD_PATH, root_path);
cd(root_path);

include(joinpath(root_path, "AmplTxt.jl"));
include(joinpath(root_path, "SCOPF.jl"));
include(joinpath(root_path, "ProductionUnits.jl"));
include(joinpath(root_path, "FakeData.jl"));

test_name = "5buses"

amplTxt = AmplTxt.read(test_name);

# TS=[1, 2]
# ECH=[0, 30, 60, 120]
# SCENARIO = ["SCENARIO_1", "SCENARIO_2"]
TS=[1]
ECH=[0]
SCENARIO = ["SCENARIO_1"]

all_uncertainties = ProductionUnits.extract_uncertainties(amplTxt, SCENARIO, TS, ECH);

ProductionUnits.write_uncertainties(all_uncertainties, joinpath(root_path, test_name, "all_uncertainties.txt"));

###
# Market simulation
###
import JuMP;
# An optimization problem
for scenario in SCENARIO, ts in TS, ech in ECH
    model = JuMP.Model();
    # une variable d'injection par groupe thermique, chaque ts-ech

    # calcul de la somme des consos résiduelles, incertitudes prises en compte

    # minimisation des couts

    # equilibre offre - demande

end


network = SCOPF.Network(amplTxt);

ref_bus = 1;
B = SCOPF.get_B(network, 1e-6);
Binv = SCOPF.get_B_inv(B, ref_bus);
PTDF = SCOPF.get_PTDF(network, Binv, ref_bus);

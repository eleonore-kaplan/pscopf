# Chemin du projet
root_path = dirname(@__DIR__)

# Import des packages et des scripts
using Dates
using Random
include(joinpath(root_path, "src", "PSCOPF.jl"));

# Paramètres à fixer
input_path = joinpath(root_path, "data", "market_test_light_2b")
output_path = joinpath(input_path, "output")
nb_scenarios = 5
mode = PSCOPF.PSCOPF_MODE_1

# Chargement du réseau
network = PSCOPF.Data.pscopfdata2network(input_path)

# Création des dimensions temporelles
ts_debut_fenetre = Dates.DateTime("2020-03-14T18:00:00") 
ts_fenetre = PSCOPF.create_target_timepoints(ts_debut_fenetre) 
liste_echeances = PSCOPF.generate_ech(network, ts_fenetre, mode) #ech: -4h, -1h, -30mins, -15mins, 0h
sequence = PSCOPF.generate_sequence(network, ts_fenetre, liste_echeances, mode)

# Création des incertitudes
Random.seed!(1234) #choix de la seed
uncertainties_distribution = PSCOPF.PSCOPFio.read_uncertainties_distributions(input_path)
uncertainties = PSCOPF.generate_uncertainties(network, ts_fenetre, liste_echeances, uncertainties_distribution, nb_scenarios)
PSCOPF.PSCOPFio.write(output_path, uncertainties)

# Création des générateurs
generators_init_state = PSCOPF.PSCOPFio.read_initial_state(input_path)

# Execution
exec_context = PSCOPF.PSCOPFContext(network, ts_fenetre, mode, generators_init_state, uncertainties, nothing, output_path)
PSCOPF.run!(exec_context, sequence)
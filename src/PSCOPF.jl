module PSCOPF
    include("abstracts.jl")

    include("bo/networks/Networks.jl")
    include("bo/modes.jl")
    include("bo/target_ts.jl")

    include("data/AmplTxt.jl")
    include("data/PSCOPFio.jl")
    include("data/DataToNetwork.jl")

    include("ech_generator.jl")
    include("uncertainties_generator.jl")
    include("context.jl")
    include("steps/steps.jl")
    include("sequence_generator.jl")
end

using .Networks

using Dates
using JuMP
using Printf

@with_kw mutable struct BalanceMarket <: AbstractMarket
    configs = EnergyMarketConfigs(problem_name = "BalanceMarket",
                                CONSIDER_TSOACTIONS_LIMITATIONS=true,
                                CONSIDER_TSOACTIONS_IMPOSITIONS=true,
                                CONSIDER_TSOACTIONS_COMMITMENTS=true,
                                REF_SCHEDULE_TYPE=PSCOPF.TSO()  #This can be the 
                                                                # TSO if TSOBilevel updates the tso_schedule according to the preceding market decided values
                                                                # or the market too cause DECIDED values refer to the preceding ECH and it is the market who launched last at the preceding ech
                                )
end

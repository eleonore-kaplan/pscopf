


const DEFAULT_CONFIGS = (
    tso_loss_of_load_penalty_value = 1e3,
    market_loss_of_load_penalty_value = 1e3,
    big_m_value = 1e4,
    tso_limit_penalty_value = 1e-3,
    tso_capping_cost = 1.,
    tso_pilotable_bounding_cost = 1.,
    market_capping_cost = 1.,

    PSCOPF_TIME_LIMIT_IN_SECONDS = nothing,
    PSCOPF_REDIRECT_LOG = false,
)

Dict{String,Any}(nt_p::NamedTuple) = Dict( string(k)=>v for (k,v) in pairs(nt_p))
const CONFIGS = Dict{String,Any}(DEFAULT_CONFIGS)

get_default_configs()::NamedTuple = DEFAULT_CONFIGS
get_configs()::Dict{String,Any} = CONFIGS
reset_configs!() = reset_configs!(CONFIGS)

function reset_configs!(configs::Dict)
    @warn("PSCOPF configs are global! Changing parameters may affect other instances execution!")
    empty!(configs)
    for (k, v) in pairs(get_default_configs())
        configs[string(k)] = v
    end
end

function get_config(config_name::String, config=CONFIGS)
    return config[config_name]
end

function get_default_config(config_name::String)
    return DEFAULT_CONFIGS[Symbol(config_name)]
end

function set_config!(config_name, value, config=CONFIGS)
    @warn("PSCOPF configs are global! Changing parameters may affect other instances execution!")
    return config[config_name] = value
end

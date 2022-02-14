abstract type AbstractDataGenerator end
function launch(launchable::AbstractDataGenerator) error("unimplemented") end

abstract type  AbstractContext end
abstract type  AbstractSchedule end

abstract type  AbstractRunnable end
function init_firmness(runnable::AbstractRunnable, ech, next_ech, TS, context::AbstractContext) error("unimplemented") end
function run(runnable::AbstractRunnable, ech, firmness, TS, context::AbstractContext) error("unimplemented") end
function affects_market_schedule(runnable::AbstractRunnable) return false end
function update_market_schedule!(market_schedule::AbstractSchedule, ech, result, firmness, context::AbstractContext, runnable::AbstractRunnable) end
function affects_tso_schedule(runnable::AbstractRunnable) return false end
function update_tso_schedule!(tso_schedule::AbstractSchedule, ech, result, firmness, context::AbstractContext, runnable::AbstractRunnable) end
function affects_tso_actions(runnable::AbstractRunnable) return false end
function update_tso_actions!(tso_actions, ech, result, firmness, context::AbstractContext, runnable::AbstractRunnable) end
#FIXME are these compatible with the Assessment step ?

abstract type  AbstractTSO <: AbstractRunnable  end
function affects_tso_schedule(runnable::AbstractTSO) return true end
function affects_tso_actions(runnable::AbstractTSO) return true end
function update_tso_schedule!(tso_schedule::AbstractSchedule, ech, result, firmness,
                            context::AbstractContext, runnable::AbstractTSO)
    error("unimplemented")
end
function update_tso_actions!(tso_actions, ech, result, firmness,
                            context::AbstractContext, runnable::AbstractTSO)
    error("unimplemented")
end

abstract type  AbstractMarket <: AbstractRunnable  end
function affects_market_schedule(runnable::AbstractMarket) return true end
function update_market_schedule!(market_schedule::AbstractSchedule, ech, result, firmness,
                                context::AbstractContext, runnable::AbstractMarket)
    error("unimplemented")
end

abstract type DeciderType end

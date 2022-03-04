abstract type AbstractDataGenerator end
function launch(launchable::AbstractDataGenerator) error("unimplemented") end

abstract type  AbstractContext end
abstract type  AbstractSchedule end

abstract type  AbstractRunnable end
function compute_firmness(runnable::AbstractRunnable, ech, next_ech, TS, context::AbstractContext) error("unimplemented") end
function run(runnable::AbstractRunnable, ech, firmness, TS, context::AbstractContext) error("unimplemented") end
function affects_market_schedule(runnable::AbstractRunnable) return false end
function update_market_schedule!(context::AbstractContext, ech, result, firmness, runnable::AbstractRunnable) end
function affects_tso_schedule(runnable::AbstractRunnable) return false end
function update_tso_schedule!(context::AbstractContext, ech, result, firmness, runnable::AbstractRunnable) end
function affects_tso_actions(runnable::AbstractRunnable) return false end
function update_tso_actions!(tso_actions, ech, result, firmness, context::AbstractContext, runnable::AbstractRunnable) end
#FIXME are these compatible with the Assessment step ?

abstract type  AbstractTSO <: AbstractRunnable  end
function affects_tso_schedule(runnable::AbstractTSO) return true end
function affects_tso_actions(runnable::AbstractTSO) return true end

abstract type  AbstractMarket <: AbstractRunnable  end
function affects_market_schedule(runnable::AbstractMarket) return true end

abstract type DeciderType end

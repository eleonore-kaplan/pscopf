abstract type AbstractDataGenerator end
function launch(launchable::AbstractDataGenerator) error("unimplemented") end

abstract type  AbstractContext end

abstract type  AbstractRunnable end
function init_firmness(runnable::AbstractRunnable, ech, next_ech, TS, context::AbstractContext) error("unimplemented") end
function run(runnable::AbstractRunnable, ech, firmness, TS, context::AbstractContext) error("unimplemented") end
function update_market_schedule!(context::AbstractContext, ech, result, firmness, runnable::AbstractRunnable) end
function update_tso_schedule!(context::AbstractContext, ech, result, firmness, runnable::AbstractRunnable) end
function update_limitations!(context::AbstractContext, ech, result, firmness, runnable::AbstractRunnable) end
function update_impositions!(context::AbstractContext, ech, result, firmness, runnable::AbstractRunnable) end
#FIXME are these compatible with the Assessment step ?

abstract type  AbstractTSO <: AbstractRunnable  end
function update_tso_schedule!(context::AbstractContext, ech, result, firmness,
                            runnable::AbstractTSO)
    error("unimplemented")
end
function update_limitations!(context::AbstractContext, ech, result, firmness,
                            runnable::AbstractTSO)
    error("unimplemented")
end
function update_impositions!(context::AbstractContext, ech, result, firmness,
                            runnable::AbstractTSO)
    error("unimplemented")
end

abstract type  AbstractMarket <: AbstractRunnable  end
function update_market_schedule!(context::AbstractContext, ech, result, firmness,
                                runnable::AbstractMarket)
    error("unimplemented")
end

abstract type DeciderType end

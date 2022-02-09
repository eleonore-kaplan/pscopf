abstract type AbstractDataGenerator end
function launch(launchable::AbstractDataGenerator) error("unimplemented") end

abstract type  AbstractContext end

abstract type  AbstractRunnable end
function run(runnable::AbstractRunnable, context::AbstractContext) error("unimplemented") end
function update!(context::AbstractContext, result, runnable::AbstractRunnable) error("unimplemented") end

abstract type  AbstractTSO <: AbstractRunnable  end
abstract type  AbstractMarket <: AbstractRunnable  end

abstract type DeciderType end

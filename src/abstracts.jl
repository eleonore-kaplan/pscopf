abstract type AbstractDataGenerator end
function launch end

abstract type AbstractGrid end

abstract type AbstractUncertaintyDist end

abstract type  AbstractRunnable end
abstract type  AbstractContext end
function run(runnable::AbstractRunnable, context::AbstractContext) error("unimplemented") end
function update!(context::AbstractContext, runnable::AbstractRunnable) error("unimplemented") end

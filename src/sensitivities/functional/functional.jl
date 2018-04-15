# Implementation of functionals (i.e. higher-order functions).
import Base.Broadcast.broadcast_shape

# Implementation of sensitivities w.r.t. `map`.
import Base.map
@primitive map(x...) where __CONTEXT__ <: ∇Ctx = propagate_forward(map, x...)

# Compute sensitivity w.r.t. the N^{th} input, N > 1.
∇(::typeof(map), ::Type{Val{N}}, p, y, ȳ, f::Function, A::∇Array...) where N =
    _∇(map, Val{N-1}, p, y, ȳ, f, A...)
_∇(::typeof(map), arg::Type{Val{N}}, p, y, ȳ, f::Function, A::∇Array...) where N =
    method_exists(∇, Tuple{typeof(f), Type{Val{N}}, Any, Any, Any, map(eltype, A)...}) ?
        map((yn, ȳn, An...)->∇(f, Val{N}, p, yn, ȳn, An...), y, ȳ, A...) :
        map((ȳn, An...)->ȳn * fmad(f, An, Val{N}), ȳ, A...)

# Implementation of sensitivities w.r.t. `broadcast`.
import Base.broadcast
@primitive broadcast(x...) where __CONTEXT__ <: ∇Ctx = propagate_forward(broadcast, x...)

"""
    broadcastsum!(f::Function, add::Bool, z, As...)

Broadcast f over As and reduce to z by summing. If add is true, then the result is added to
the current value of z, otherwise it is overwritten.
"""
function broadcastsum!(f::Function, add::Bool, z, As...)
    tmp_shape = broadcast_shape(map(size, As)...)
    if size(z) != tmp_shape
        tmp = Array{eltype(z)}(tmp_shape)
        return sum!(z, broadcast!(f, tmp, As...), init=!add)
    else
        return add ?
            broadcast!((z, x...)->z + f(x...), z, z, As...) :
            broadcast!(f, z, As...)
    end
end

"""
    broadcastsum(f::Function, add::Bool, z::AbstractArray, As...)

Allocating version of broadcastsum! specialised for Arrays.
"""
broadcastsum(f::Function, add::Bool, z::AbstractArray, As...) =
    broadcastsum!(f, add, Array{eltype(z)}(size(z)), As...)

"""
    broadcastsum(f::Function, add::Bool, z::Number, As...)

Specialisation of broadcastsum to Number-sized outputs.
"""
function broadcastsum(f::Function, add::Bool, z::Number, As...)
    tmp = Array{eltype(z)}(undef, broadcast_shape(map(size, As)...))
    return sum(broadcast!(f, tmp, As...)) + (add ? z : zero(z))
end

# Compute sensitivity w.r.t. the N^{th} input, N > 1.
∇(::typeof(broadcast), ::Type{Val{N}}, p, y, ȳ, f::Function, A::∇ArrayOrScalar...) where N =
    _∇(broadcast, Val{N-1}, p, y, ȳ, f, A...)
_∇(::typeof(broadcast), ::Type{Val{N}}, p, y, ȳ, f, A...) where N =
    hasmethod(∇, Tuple{typeof(f), Type{Val{N}}, Any, Any, Any, map(eltype, A)...}) ?
        broadcastsum((yn, ȳn, xn...)->∇(f, Val{N}, p, yn, ȳn, xn...), false, A[N], y, ȳ, A...) :
        broadcastsum((ȳn, xn...)->ȳn * fmad(f, xn, Val{N}), false, A[N], ȳ, A...)

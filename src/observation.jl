"""
    numobs(data)

Return the total number of observations contained in `data`.

See also [`getobs`](@ref)
"""
function numobs end

"""
    getobs(data, [idx])

Return the observations corresponding to the observation-index `idx`.
Note that `idx` can be any type as long as `data` has defined
`getobs` for that type.

The returned observation(s) should be in the form intended to
be passed as-is to some learning algorithm. There is no strict
interface requirement on how this "actual data" must look like.

Every author behind some custom data container can make this
decision themselves.

The output should be consistent when `idx` is a scalar vs vector.

See also [`getobs!`](@ref) and [`numobs`](@ref) 
"""
function getobs end

# Generic Fallbacks
getobs(data) = data
# getobs(data, idx) = data[idx]

"""
    getobs!(buffer, data, idx)

Inplace version of `getobs(data, idx)`. If this method
is defined for the type of `data`, then `buffer` should be used
to store the result, instead of allocating a dedicated object.

Implementing this function is optional. In the case no such
method is provided for the type of `data`, then `buffer` will be
*ignored* and the result of [`getobs`](@ref) returned. This could be
because the type of `data` may not lend itself to the concept
of `copy!`. Thus, supporting a custom `getobs!` is optional
and not required.
"""
function getobs! end
# getobs!(buffer, data) = getobs(data)
getobs!(buffer, data, idx) = getobs(data, idx)

# --------------------------------------------------------------------
# AbstractDataContainer
# Having an AbstractDataContainer allows to define sensible defaults
# for Base (or other) interfaces based on our interface.
# This makes it easier for developers by reducing boilerplate.

abstract type AbstractDataContainer end

Base.getindex(x::AbstractDataContainer, i) = getobs(x, i)
Base.length(x::AbstractDataContainer) = numobs(x)
Base.size(x::AbstractDataContainer) = (length(x),)

Base.iterate(x::AbstractDataContainer, state = 1) =
    (state > length(x)) ? nothing : (x[state], state + 1)
Base.lastindex(x::AbstractDataContainer) = length(x)

# --------------------------------------------------------------------
# Arrays
# We are very opinionated with arrays: the observation dimension
# is th last dimension. For different behavior wrap the array in 
# a custom type, e.g. with Tables.table.


numobs(A::AbstractArray{<:Any, N}) where {N} = size(A, N)

# 0-dim arrays
numobs(A::AbstractArray{<:Any, 0}) = 1

function getobs(A::AbstractArray{<:Any, N}, idx) where N
    I = ntuple(_ -> :, N-1)
    return A[I..., idx]
end

getobs(A::AbstractArray{<:Any, 0}, idx) = A[idx]

function getobs!(buffer::AbstractArray, A::AbstractArray{<:Any, N}, idx) where N
    I = ntuple(_ -> :, N-1)
    buffer .= A[I..., idx]
    return buffer
end

function getobs!(buffer::AbstractArray, A::AbstractArray)
    buffer .= A
    return buffer
end

# --------------------------------------------------------------------
# Tuples and NamedTuples

_check_numobs_error() =
    throw(DimensionMismatch("All data containers must have the same number of observations."))

function _check_numobs(data::Union{Tuple, NamedTuple, Dict})
    length(data) == 0 && return 0
    n = numobs(data[first(keys(data))])

    for i in keys(data)
        ni = numobs(data[i])
        n == ni || _check_numobs_error()
    end
    return n
end

numobs(data::Union{Tuple, NamedTuple}) = _check_numobs(data)


getobs(tup::Union{Tuple, NamedTuple}) = map(x -> getobs(x), tup)

function getobs(tup::Union{Tuple, NamedTuple}, indices)
    _check_numobs(tup)
    return map(x -> getobs(x, indices), tup)
end

function getobs!(buffers::Union{Tuple, NamedTuple},
                 tup::Union{Tuple, NamedTuple},
                 indices)
    _check_numobs(tup)

    return map(buffers, tup) do buffer, x
        getobs!(buffer, x, indices)
    end
end

## Dict

numobs(data::Dict) = _check_numobs(data)

getobs(data::Dict, i) = Dict(k => getobs(v, i) for (k, v) in pairs(data))

getobs(data::Dict) = Dict(k => getobs(v) for (k, v) in pairs(data))

function getobs!(buffers, data::Dict, i)
    for (k, v) in pairs(data)
        getobs!(buffers[k], v, i)
    end

    return buffers
end

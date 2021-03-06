# Use BLAS.gemm for strided matrix-matrix multiplication sensitivites. Don't bother with
# BLAS for matrix-vector stuff yet. Definitely an optimisation that we might want to
# consider at some point in the future though.
const RS = StridedMatrix{<:∇Scalar}
const RST = Transpose{<:∇Scalar, RS}
const RSA = Adjoint{<:∇Scalar, RS}
strided_matmul = [
    (RS,  RS,  'N', 'C', :Ȳ, :B, 'C', 'N', :A, :Ȳ),
    (RST, RS,  'N', 'T', :B, :Ȳ, 'N', 'N', :A, :Ȳ),
    (RS,  RST, 'N', 'N', :Ȳ, :B, 'T', 'N', :Ȳ, :A),
    (RST, RST, 'T', 'T', :B, :Ȳ, 'T', 'T', :Ȳ, :A),
    (RSA, RS,  'N', 'C', :B, :Ȳ, 'N', 'N', :A, :Ȳ),
    (RS,  RSA, 'N', 'N', :Ȳ, :B, 'C', 'N', :Ȳ, :A),
    (RSA, RSA, 'C', 'C', :B, :Ȳ, 'C', 'C', :Ȳ, :A),
]
import Base: *
for (TA, TB, tCA, tDA, CA, DA, tCB, tDB, CB, DB) in strided_matmul

    # Add intercepts and export names.
    @eval @explicit_intercepts $(Symbol("*")) Tuple{$TA, $TB}

    # Define allocating and non-allocating sensitivities for each output.
    alloc_Ā = :(LinearAlgebra.BLAS.gemm($tCA, $tDA, $CA, $DA))
    alloc_B̄ = :(LinearAlgebra.BLAS.gemm($tCB, $tDB, $CB, $DB))
    no_alloc_Ā = :(LinearAlgebra.BLAS.gemm!($tCA, $tDA, 1., $CA, $DA, 1., Ā))
    no_alloc_B̄ = :(LinearAlgebra.BLAS.gemm!($tCB, $tDB, 1., $CB, $DB, 1., B̄))

    # Add sensitivity definitions.
    @eval ∇(::typeof(*), ::Type{Arg{1}}, p, Y::RS, Ȳ::RS, A::$TA, B::$TB) = $alloc_Ā
    @eval ∇(::typeof(*), ::Type{Arg{2}}, p, Y::RS, Ȳ::RS, A::$TA, B::$TB) = $alloc_B̄
    @eval ∇(Ā, ::typeof(*), ::Type{Arg{1}}, p, Y::RS, Ȳ::RS, A::$TA, B::$TB) = $no_alloc_Ā
    @eval ∇(B̄, ::typeof(*), ::Type{Arg{2}}, p, Y::RS, Ȳ::RS, A::$TA, B::$TB) = $no_alloc_B̄
end

# # Not every permutation of transpositions makes sense for matrix-vector multiplication. This
# # list just includes those which make sense.
# strided_matvecmul = [
#     (:*,         'C', :ȳ, :b, 'C'),
#     (:At_mul_B,  'T', :b, :ȳ, 'N'),
#     (:Ac_mul_B,  'C', :b, :ȳ, 'N'),
# ]
# for (f, tdA, CA, dA, tCb) in strided_matvecmul
#     n_Ā, u_Ā = tdA == 'C' ? :(Ā = $CA * $dA') : :(Ā = $CA * $dA'), :(ger!(1., $CA, $dA, Ā))
#     n_b̄, u_b̄ = :(b̄ = gemv($tCb, A, ȳ)), :(b̄ = gemv!($tCb, 1., A, ȳ, 1., b̄))
#     generate_primitive(f, [:(T <: StridedMatrix), :(V <: StridedVector)],
#         [:A, :b], [:Ā, :b̄], [:T, :V], [true, true], :y, :ȳ, [n_Ā, n_b̄], [u_Ā, u_b̄])
# end

# # Operations of the for Y = A \ B
# strided_ldiv = [
#     (:\, :(C = At_ldiv_B(A, Ȳ)), 'N', 'T', :C, :Y),
#     (:At_ldiv_B, :(C = A \ Ȳ), 'N', 'T', :Y, :C),
#     (:A_ldiv_Bt, :(C = At_rdiv_B(Ȳ, A)), 'T', 'T', :C, :Y),
#     (:At_ldiv_Bt, :(C = At_rdiv_Bt(Ȳ, A)), 'N', 'N', :Y, :C),
#     (:Ac_ldiv_B, :(C = A \ Ȳ), 'N', 'C', :Y, :C),
#     (:A_ldiv_Bc, :(C = Ac_rdiv_B(Ȳ, A)), 'C', 'C', :C, :Y),
#     (:Ac_ldiv_Bc, :(C = Ac_rdiv_Bc(Ȳ, A)), 'N', 'N', :Y, :C),
# ]

# # Iterate through primitive definitions and add methods for each.
# for (f, C, tA, tB, arg1, arg2) in strided_ldiv
#     new_Ā = :(Ā = gemm($tA, $tB, -1.0, $arg1, $arg2))
#     update_Ā = :(gemm!($tA, $tB, -1.0, $arg1, $arg2, 1.0, Ā))
#     new_B̄ = :(B̄ = C)
#     update_B̄ = :(broadcast!((b̄, c)->b̄ + c, B̄, B̄, C))
#     generate_primitive(f, [:(T <: Any), :(V <: Any)],
#         [:A, :B], [:Ā, :B̄], [:T, :V], [true, true], :Y, :Ȳ,
#         [new_Ā, new_B̄], [update_Ā, update_B̄], C)
# end

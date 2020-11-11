# we take a Singular ideal and extract the following data:
# an int array lengths storing the lengths of each generator
# an int array cfs storing the coefficients of each generator
# an int array exps storing the exponent vectors of each generator
function convert_ff_singular_ideal_to_array(
        id::Singular.sideal,
        nvars::Int,
        ngens::Int
        )
    nterms  = 0
    lens = Array{Int32,1}(undef, ngens)
    for i = 1:ngens
        lens[i] =   Singular.length(id[i])
        nterms  +=  lens[i]
    end
    cfs   = Array{Int32,1}(undef, nterms)
    exps  = Array{Int32,1}(undef, nvars*nterms)
    cc = 1 # coefficient counter
    ec = 0 # exponent vector counter
    for i = 1:Singular.ngens(id)
        for c in Singular.coeffs(id[i])
            cfs[cc] = Base.Int(c)
            cc += 1
        end
        for e in Singular.exponent_vectors(id[i])
            for j = 1:nvars
                exps[nvars*ec+j]  =  Base.Int(e[j])
            end
            ec +=  1
        end
    end
    lens, cfs, exps
end

function convert_qq_singular_ideal_to_array(
        id::Singular.sideal,
        nvars::Int,
        ngens::Int
        )
    nterms  = 0
    lens = Array{Int32,1}(undef, ngens)
    for i = 1:ngens
        lens[i] =   Singular.length(id[i])
        nterms  +=  lens[i]
    end
    cfs   = Array{BigInt,1}(undef, 2*nterms)
    exps  = Array{Int32,1}(undef, nvars*nterms)
    cc = 1 # coefficient counter
    ec = 0 # exponent vector counter
    for i = 1:Singular.ngens(id)
        for c in Singular.coeffs(id[i])
            cfs[cc] = Singular.libSingular.n_GetMPZ(numerator(c).ptr, Singular.ZZ.ptr)
            cc += 1
            cfs[cc] = Singular.libSingular.n_GetMPZ(denominator(c).ptr, Singular.ZZ.ptr)
            cc += 1
        end
        for e in Singular.exponent_vectors(id[i])
            for j = 1:nvars
                exps[nvars*ec+j]  =  Base.Int(e[j])
            end
            ec +=  1
        end
    end
    lens, cfs, exps
end

# we know that the terms are already sorted and they are all different
# coming from GroebnerBasis' F4 computation, so we do not need p_Add_q for
# the terms, but we can directly set the next pointers of the polynomials
function convert_ff_gb_array_to_singular_ideal(
        bld::Int32,
        blen::Array{Int32,1},
        bexp::Array{Int32,1},
        bcf::Array{Int32,1},
        R::Singular.PolyRing
        )
    ngens = bld

    nvars = Singular.nvars(R)
    basis = Singular.Ideal(R, ) # empty ideal
    # first entry in exponent vector is module component => nvars+1
    exp   = zeros(Cint, nvars+1)

    list  = elem_type(R)[]
    # we generate the singular polynomials low level in order
    # to avoid overhead due to many exponent operations etc.
    j   = ngens + 1 + 1
    len = 1
    for i = 1:ngens
        # do the first term
        p = Singular.libSingular.p_Init(R.ptr)
        Singular.libSingular.pSetCoeff0(p, Clong(bcf[len]), R.ptr)
        for k = 1:nvars
            exp[k+1]  = bexp[(len-1) * nvars + k]
        end
        Singular.libSingular.p_SetExpV(p, exp, R.ptr)
        lp  = p
        for j = 2:blen[i]
          pterm = Singular.libSingular.p_Init(R.ptr)
          Singular.libSingular.pSetCoeff0(pterm, Clong(bcf[len+j-1]), R.ptr)
          for k = 1:nvars
              exp[k+1]  = bexp[(len+j-1-1) * nvars + k]
          end
          Singular.libSingular.p_SetExpV(pterm, exp, R.ptr)
          Singular.libSingular.SetpNext(lp, pterm)
          lp  = pterm
        end
        push!(list, R(p))
        len += blen[i]
    end
    return Singular.Ideal(R, list)
end

function convert_qq_gb_array_to_singular_ideal(
        bld::Int32,
        blen::Array{Int32,1},
        bexp::Array{Int32,1},
        bcf::Ptr{T} where {T <: Signed},
        R::Singular.PolyRing
        )
    ngens = bld

    nvars = Singular.nvars(R)
    basis = Singular.Ideal(R, ) # empty ideal
    # first entry in exponent vector is module component => nvars+1
    exp   = zeros(Cint, nvars+1)

    list  = elem_type(R)[]
    # we generate the singular polynomials low level in order
    # to avoid overhead due to many exponent operations etc.
    j   = ngens + 1 + 1
    len = 1
    for i = 1:ngens
        # do the first term
        p = Singular.libSingular.p_Init(R.ptr)
        Singular.libSingular.p_SetCoeff0(p,
                Singular.libSingular.n_InitMPZ(BigInt(unsafe_load(bcf, len)),
                    Singular.QQ.ptr), R.ptr)
        for k = 1:nvars
            exp[k+1]  = bexp[(len-1) * nvars + k]
        end
        Singular.libSingular.p_SetExpV(p, exp, R.ptr)
        lp  = p
        for j = 2:blen[i]
          pterm = Singular.libSingular.p_Init(R.ptr)
        Singular.libSingular.p_SetCoeff0(pterm,
                Singular.libSingular.n_InitMPZ(BigInt(unsafe_load(bcf, len+j-1)),
                    Singular.QQ.ptr), R.ptr)
          for k = 1:nvars
              exp[k+1]  = bexp[(len+j-1-1) * nvars + k]
          end
          Singular.libSingular.p_SetExpV(pterm, exp, R.ptr)
          Singular.libSingular.SetpNext(lp, pterm)
          lp  = pterm
        end
        push!(list, R(p))
        len += blen[i]
    end
    return Singular.Ideal(R, list)
end
function test()
    lib = Libdl.dlopen(libgb)
    sym = Libdl.dlsym(lib, :min_example)
    ccall(sym, Nothing, ())
end
"""
    f4(I[, hts::Int=17, nthrds::Int=1, maxpairs::Int=0, resetht::Int=0,
            laopt::Int=1, infolevel::Int=0, monorder::Symbol=:degrevlex])

Compute a Groebner basis of the given ideal I w.r.t. to the given monomial
order using Faugere's F4 algorithm. The function takes a Singular ideal as
input and returns a Singular ideal. At the moment only finite fields up to
31-bit and the rationals are supported as ground fields.

# Arguments
* `I::Singular.sideal`: ideal to compute a Groebner basis for.
* `hts::Int=17`: hash table size log_2; default is 17, i.e. 2^17 as initial hash
                table size.
* `nthrds::Int=1`:  number of threads; default is 1.
* `maxpairs::Int=0`:  maximal number of pairs selected for one matrix; default is
                      0, i.e. no restriction. If matrices get too big or consume
                      too much memory this is a good parameter to play with.
* `resetht::Int=0`: Resets the hash table after `resetht` steps in the algorthm;
                    default is 0, i.e. no resetting at all. Since we add
                    monomials to the matrices which are only used for reduction
                    purposes, but have no further meaning in the basis, this
                    parameter might also help when memory get a problem.
* `laopt::Int=1`: option for linear algebra to be used. there are different
                  linear algebra routines implemented:
    -  `1`: exact sparse-dense computation (default),
    -  `2`: exact sparse computation,
    - `42`: probabilistic sparse-dense computation,
    - `43`: exact sparse then probabilistic dense computation,
    - `44`: probabilistic sparse computation.
* `reducegb::Int=0`:  reduce final basis; default is 0. Note that for
                      computations over Q we do not normalize the polynomials,
                      the basis is only minimal and tailreduced. Normalize by
                      hand if necessary.
* `pbmfiles::Int=0`: option for generating pbm files of matrices:
    - `0`: off (default),
    - `1`:  on.
* `infolevel::Int=0`: info level for printout:
    - `0`: no printout (default),
    - `1`:  a summary of the computational data is printed at the beginning and
    the end of the computation,
    - `2`: also dynamical information for each round resp. matrix is printed.
* `monorder::Symbol=:degrevlex`: monomial order w.r.t. which the computation is
                                done;
    - `degrevlex`: the degree-reverse-lexicographical (DRL) order (default),
    - `lex`: the lexicographical order (LEX).
"""
function f4(
        I::Singular.sideal;           # input generators
        hts::Int=17,                  # hash table size, default 2^17
        nthrds::Int=1,                # number of threads
        maxpairs::Int=0,              # number of pairs maximally chosen
                                      # in symbolic preprocessing
        resetht::Int=0,               # resetting global hash table
        laopt::Int=2,                 # linear algebra option
        reducegb::Int=0,              # reduce final basis
        pbmfiles::Int=0,              # generation of pbm files
        infolevel::Int=0,             # info level for print outs
        monorder::Symbol=:dregrevlex  # monomial order
        )
    R     = I.base_ring
    # skip zero generators in ideal
    ptr = Singular.libSingular.id_Copy(I.ptr, R.ptr)
    J   = Singular.Ideal(R, ptr)
    Singular.libSingular.idSkipZeroes(J.ptr)
    # get number of variables
    nvars   = Singular.nvars(R)
    ngens   = Singular.ngens(J)

    ord = 0
    if monorder == :degrevlex
        ord = 0
    end
    if monorder == :lex
        ord = 1
    end
    char  = Singular.characteristic(R)

    # convert Singular ideal to flattened arrays of ints
    if 0 == char
      lens, cfs, exps   = convert_qq_singular_ideal_to_array(J, nvars, ngens)
    elseif Nemo.isprime(FlintZZ(char))
      lens, cfs, exps   = convert_ff_singular_ideal_to_array(J, nvars, ngens)
    else
        error("At the moment GroebnerBasis only supports finite fields and the rationals.")
    end
    lib = Libdl.dlopen(libgb)
    sym = Libdl.dlsym(lib, :f4_julia)

    gb_ld   = ccall(:malloc, Ptr{Cint}, (Csize_t, ), sizeof(Cint))
    gb_len  = ccall(:malloc, Ptr{Ptr{Cint}}, (Csize_t, ), sizeof(Ptr{Cint}))
    gb_exp  = ccall(:malloc, Ptr{Ptr{Cint}}, (Csize_t, ), sizeof(Ptr{Cint}))
    gb_cf   = ccall(:malloc, Ptr{Ptr{Cvoid}}, (Csize_t, ), sizeof(Ptr{Cvoid}))
    nterms  = ccall(sym, Int,
        (Ptr{Cint}, Ptr{Ptr{Cint}}, Ptr{Ptr{Cint}}, Ptr{Ptr{Cvoid}},
          Ptr{Cint}, Ptr{Cint}, Ptr{Cvoid}, Int, Int, Int, Int, Int,
          Int, Int, Int, Int, Int, Int, Int),
        gb_ld, gb_len, gb_exp, gb_cf, lens, exps, cfs, char, ord, nvars,
        ngens, hts, nthrds, maxpairs, resetht, laopt, reducegb, pbmfiles, infolevel)
    Libdl.dlclose(lib)

    if nterms == 0
        error("Something went wrong in the C code of F4.")
    end
    # convert to julia array, also give memory management to julia
    jl_ld   = unsafe_load(gb_ld)
    jl_len  = Base.unsafe_wrap(Array, unsafe_load(gb_len), jl_ld)
    jl_exp  = Base.unsafe_wrap(Array, unsafe_load(gb_exp), nterms*nvars)
    if 0 == char
        gb_cf_conv  = unsafe_load(gb_cf)
        jl_cf       = reinterpret(Ptr{BigInt}, gb_cf_conv)
    elseif Nemo.isprime(FlintZZ(char))
      gb_cf_conv  = Ptr{Ptr{Int32}}(gb_cf)
      jl_cf       = Base.unsafe_wrap(Array, unsafe_load(gb_cf_conv), nterms)
    end

    # construct Singular ideal
    if 0 == char
        basis = convert_qq_gb_array_to_singular_ideal(
          jl_ld, jl_len, jl_exp, jl_cf, R)
    elseif Nemo.isprime(FlintZZ(char))
        basis = convert_ff_gb_array_to_singular_ideal(
          jl_ld, jl_len, jl_exp, jl_cf, R)
    end
    lib = Libdl.dlopen(libgb)
    sym = Libdl.dlsym(lib, :free_julia_data)
    ccall(sym, Nothing , (Ptr{Ptr{Cint}}, Ptr{Ptr{Cint}}, Ptr{Ptr{Cvoid}},
                Int, Int), gb_len, gb_exp, gb_cf, jl_ld, char)
    # free data
    ccall(:free, Nothing , (Ptr{Cint}, ), gb_ld)

    # for letting the garbage collector free memory
    jl_len      = Nothing
    jl_exp      = Nothing
    gb_cf_conv  = Nothing
    jl_cf       = Nothing

    basis.isGB  = true;

    return basis
end

#function mf4(
#        I::Singular.sideal;           # input generators
#        hts::Int=17,                  # hash table size, default 2^17
#        nthrds::Int=1,                # number of threads
#        maxpairs::Int=0,              # number of pairs maximally chosen
#                                    # in symbolic preprocessing
#        resetht::Int=0,               # resetting global hash table
#        laopt::Int=2,                 # linear algebra option
#        pbmfiles::Int=0,              # generation of pbm files
#        infolevel::Int=0,             # info level for print outs
#        monorder::Symbol=:dregrevlex  # monomial order
#        )
#    R     = I.base_ring
#    char  = Singular.characteristic(R)
#    if 0 != char
#        if Hecke.isprime(char)
#            println("Characteristic is ", char, " != 0.",
#                    " Trying finite field computation")
#            return f4(I, hts=hts, nthrds=nthrds, maxpairs=maxpairs,
#                resetht=resetht, laopt=laopt, pbmfiles=pbmfiles,
#                infolevel=infolevel, monorder=monorder)
#        else
#            error("Only finite fields and rationals are supported ",
#                    "at the moment.")
#        end
#    end
#    # skip zero generators in ideal
#    ptr = Singular.libSingular.id_Copy(I.ptr, R.ptr)
#    J   = Singular.Ideal(R, ptr)
#    Singular.libSingular.idSkipZeroes(J.ptr)
#    # get number of variables
#    nvars   = Singular.nvars(R)
#    ngens   = Singular.ngens(J)
#    # convert Singular ideal to flattened arrays of ints
#    lens, cfs, exps   = convert_ff_singular_ideal_to_array(J, nvars, ngens)
#    # call f4 in gb
#    #  println("Input data")
#    #  println("----------")
#    #  println(lens)
#    #  println(cfs)
#    #  println(exps)
#    #  println("----------")
#    #if hts > 30
#    #    hts = 24
#    #  end
#    ord = 0
#    if monorder == :degrevlex
#        ord = 0
#    end
#    if monorder == :lex
#        ord = 1
#    end
#    # calling f4_julia with the following arguments:
#    # lengths of all generators
#    # coefficients of all generators
#    # exponents of all generators
#    # number of variables
#    # number of generators
#    # hash table size log_2, i.e. given 12 => 2^12
#    # println(char, nvars, ngens, hts, nthrds, maxpairs, laopt)
#    lib = Libdl.dlopen(libgb)
#    sym = Libdl.dlsym(lib, :mod_f4_julia)
#    gb_ld   = ccall((:malloc, "libc.so.6"), Ptr{Cint}, (Csize_t, ), sizeof(Cint))
#    gb_len  = ccall((:malloc, "libc.so.6"), Ptr{Ptr{Cint}}, (Csize_t, ), sizeof(Ptr{Cint}))
#    gb_exp  = ccall((:malloc, "libc.so.6"), Ptr{Ptr{Cint}}, (Csize_t, ), sizeof(Ptr{Cint}))
#    gb_cf   = ccall((:malloc, "libc.so.6"), Ptr{Ptr{Cvoid}}, (Csize_t, ), sizeof(Ptr{Cvoid}))
#    nterms  = ccall(sym, Int,
#        (Ptr{Cint}, Ptr{Ptr{Cint}, Ptr{Ptr{Cint}}}, Ptr{Ptr{Cvoid}},
#          Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Int, Int, Int, Int, Int,
#          Int, Int, Int, Int, Int, Int),
#        gb_ld, gb_len, gb_exp, gb_cf, lens, cfs, exps, char, ord, nvars,
#        ngens, hts, nthrds, maxpairs, resetht, laopt, pbmfiles, infolevel)
#    Libdl.dlclose(lib)
#
#    if nterms == 0
#        error("Something went wrong in the C code of F4.")
#    end
#    # convert to julia array, also give memory management to julia
#    jl_ld_a = Base.unsafe_wrap(Array, unsafe_load(gb_ld), 1; own=true)
#    jl_ld   = jl_ld_a[1]
#    jl_len  = Base.unsafe_wrap(Array, unsafe_load(gb_len), jl_ld; own=true)
#    jl_exp  = Base.unsafe_wrap(Array, unsafe_load(gb_exp), jl_ld*nterms*nvars; own=true)
#    jl_cf   = Base.unsafe_wrap(Array, unsafe_load(gb_exp), jl_ld*nterms; own=true)
#    println(typeof(jl_cf))
#    ccall((:free, "libc.so.6"), Nothing , (Ptr{Ptr{Cint}}, ), gb_basis)
#    basis       = convert_ff_gb_array_to_singular_ideal(jl_basis, R)
#    basis.isGB  = true;
#
#    return basis
#end

function f4q(
        I::Array{Singular.sideal,1};           # input generators
        hts::Int=17,                  # hash table size, default 2^17
        nthrds::Int=1,                # number of threads
        maxpairs::Int=0,              # number of pairs maximally chosen
                                    # in symbolic preprocessing
        resetht::Int=0,               # resetting global hash table
        laopt::Int=2,                 # linear algebra option
        pbmfiles::Int=0,              # generation of pbm files
        infolevel::Int=0,             # info level for print outs
        monorder::Symbol=:dregrevlex  # monomial order
        )

    if length(I) <= 0
        return
    end

    R     = []
    char  = []
    lens  = []
    cfs   = []
    exps  = []
    # get number of variables
    nvars   = Singular.nvars(I[1].base_ring)
    ngens   = Singular.ngens(I[1])
    # for i in 1:length(I)
    for i in 1:nthrds
        push!(R, I[i].base_ring)
        push!(char, Singular.characteristic(R[i]))
        # convert Singular ideal to flattened arrays of ints
        ret = convert_ff_singular_ideal_to_array(I[i], nvars, ngens)
        push!(lens, ret[1])
        push!(cfs, ret[2])
        push!(exps, ret[3])
    end
    ord = 0
    if monorder == :degrevlex
        ord = 0
    end
    if monorder == :lex
        ord = 1
    end
    jl_basis  = []
    gb_basis  = []
    gb_basis_len  = Array{Int32,1}(undef,nthrds)
    for i in 1:nthrds
        push!(gb_basis,ccall((:malloc, "libc.so.6"), Ptr{Ptr{Cint}}, (Csize_t, ),
                    sizeof(Ptr{Cint})))
    end
    println("nthrds ", nthrds)
        lib = Libdl.dlopen(libgb)
        sym = Libdl.dlsym(lib, :f4_julia)
    Threads.@threads for i in 1:nthrds
        gb_basis_len[i]  = ccall(sym, Int,
            (Ptr{Ptr{Cint}}, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Int, Int, Int, Int, Int,
            Int, Int, Int, Int, Int, Int),
            gb_basis[i], lens[i], cfs[i], exps[i], char[i], ord, nvars, ngens,
            hts, 1, maxpairs,
            resetht, laopt, pbmfiles, infolevel)
    end
        Libdl.dlclose(lib)
    res = []
    for i in 1:nthrds
        push!(jl_basis, Base.unsafe_wrap(Array, unsafe_load(gb_basis[i]),
                    gb_basis_len[i]; own=true))
        ccall((:free, "libc.so.6"), Nothing , (Ptr{Ptr{Cint}}, ), gb_basis[i])
        push!(res, convert_gb_array_to_singular_ideal(jl_basis[i], R[i]))
        res[i].isGB  = true;
    end

    return res
end

# function map_ideal(
#         I::Singular.sideal,
#         p
#         )
#     pp      = Hecke.next_prime(p)
#     R       = base_ring(I)
#     vars    = string.(Singular.gens(R))
#     Fp      = Singular.N_ZpField(pp)
#     # skip zero generators in ideal
#     ptr     = Singular.libSingular.id_Copy(I.ptr, R.ptr)
#     J       = Singular.Ideal(R, ptr)
#     Singular.libSingular.idSkipZeroes(J.ptr)
#     Rp, Xp  = Singular.PolynomialRing(Fp, vars, cached=false)
#     global Xp
#     [ eval(Meta.parse("$s = Xp[$i]")) for (i, s) in enumerate(vars) ]
#     id  = [string(J[k]) for k in 1:Singular.ngens(J)]
#     Ip  = Singular.Ideal(Rp, [eval(Meta.parse("$poly")) for poly in id])
#     Ip
# end
#
# function modf4(
#         I::Singular.sideal;           # input generators
#         hts::Int=17,                  # hash table size, default 2^17
#         nthrds::Int=1,                # number of threads
#         maxpairs::Int=0,              # number of pairs maximally chosen
#                                       # in symbolic preprocessing
#         resetht::Int=0,               # resetting global hash table
#         laopt::Int=2,                 # linear algebra option
#         pbmfiles::Int=0,              # generation of pbm files
#         infolevel::Int=0,             # info level for print outs
#         monorder::Symbol=:dregrevlex  # monomial order
#         )
#     ZX, X = FlintZZ['X']
#     # prime characteristic
#     p     = 2^29
#     pp    = fmpz(1)
#
#     pl  = Array{Int,1}(undef,nthrds)
#     Il  = Array{Singular.sideal,1}(undef,nthrds)
#     for i in 1:nthrds
#         pl[i] = next_prime(p)
#         p     = pl[i]
#         Il[i] = map_ideal(I,pl[i])
#     end
#     res  = GroebnerBasis.f4q(Il, hts=hts, nthrds=nthrds,
#             maxpairs=maxpairs, resetht=resetht, laopt=laopt,
#             pbmfiles=pbmfiles, infolevel=infolevel, monorder=monorder)
#     return res
# end
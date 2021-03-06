# GroebnerBasis

[![Build Status](https://travis-ci.org/ederc/GroebnerBasis.jl.svg?branch=master)](https://travis-ci.org/ederc/GroebnerBasis.jl)

This is a julia library which provides an interface between **Singular**
(https://github.com/Singular/Sources) and **gb** (https://github.com/ederc/gb).

It depends on **Singular.jl** (https://github.com/oscar-system/Singular.jl) for using
Singular in julia.

The package also provides a benchmark suite for various different Groebner basis
computations, see **Benchmarks.jl**.

In **Example.jl** we provide a small example for how to call the main functions
of the package. E.g. in your julia session call
```julia
using GroebnerBasis
GroebnerBasis.run_cyclic_8()
```

This work is partly supported by the DFG Sonderforschungsbereich TRR 195.

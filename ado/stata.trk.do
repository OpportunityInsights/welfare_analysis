* 00000002
*! version 1.0.0
* Do not erase or edit this file
* It is used by Stata to track the ado and help
* files you have installed.

S http://fmwww.bc.edu/repec/bocode/s
N sxpose.pkg
D  9 Nov 2018
U 1
d 'SXPOSE': module to transpose string variable dataset
d 
d sxpose transposes a dataset of string variables,  so that
d observations become variables, and vice versa. It is a rough and
d ready utility: use circumspectly. With a force option, datasets
d containing numeric variables may also be transposed.
d 
d KW:  transpose
d KW: xpose
d KW: data management
d 
d Requires: Stata version 8.2
d 
d Distribution-Date: 20041015
d 
d Author: Nicholas J. Cox, Durham University
d Support: email N.J.Cox@@durham.ac.uk
d 
f s/sxpose.ado
f s/sxpose.hlp
e
S http://fmwww.bc.edu/repec/bocode/p
N parallel.pkg
D 14 Jan 2019
U 2
d 'PARALLEL': module for Parallel Computing
d 
d   Parallel lets you run Stata faster, sometimes faster than MP
d itself. By organizing your job in several Stata instances,
d parallel allows you to work with out-of-the-box parallel
d computing. Using the the 'parallel' prefix, you can get faster
d simulations, bootstrapping, reshaping big data, etc. without
d having to know a thing about parallel computing. With no need of
d having Stata/MP installed on your computer, parallel has showed
d to dramatically speedup computations up to two, four, or more
d times depending on how many processors your computer has.
d 
d KW: parallel computing
d KW: timming
d KW: high performance computing
d KW: HPC
d KW: big data
d KW: simulations
d KW: bootstrapping
d KW: monte carlo
d KW: multiple imputations
d 
d Requires: Stata version 11
d 
d Distribution-Date: 20150829
d 
d Author: George Vega Yon , Superintendencia de Pensiones, Chile
d Support: email gvega@@spensiones.cl
d 
d Author: Brian Quistorff, University of Maryland
d Support: email bquistorff@@gmail.com
d 
f p/parallel.ado
f p/parallel_append.ado
f p/parallel_bs.ado
f p/parallel_sim.ado
f p/parallel.sthlp
f p/parallel_source.sthlp
f l/lparallel.mlib
e

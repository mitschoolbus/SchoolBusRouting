# SchoolBusRouting

This is a simple Julia package to reproduce our school bus routing results on synthetic benchmarks from Park, Tae and Kim (2011). To use the package, you will need to have Julia 0.6 installed on your machine.

You can then download the package by running the following command in the Julia REPL:
```julia
julia> Pkg.clone("https://github.com/adelarue/SchoolBusRouting.git")
```
You can then run `Pkg.resolve()` to install all open-source dependencies. Note that in order to use the package, you must have Gurobi and an appropriate license installed on your machine. Instructions on obtaining Gurobi and an academic license can be found at https://www.gurobi.com/downloads/download-center

Reproducing the results from the article can be done by running the code in `examples/pnas.jl`.

If you use any of this code in your research, please cite our article!

Authors: Dimitris Bertsimas, Arthur Delarue, Sebastien Martin

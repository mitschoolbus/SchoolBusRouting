# SchoolBusRouting

This is a simple Julia package to reproduce our school bus routing results on synthetic benchmarks from Park, Tae and Kim (2011). To use the package, you will need to have Julia 0.6 installed on your machine.

You can then download the package by running the following command in the Julia REPL:
```julia
julia> Pkg.clone("https://github.com/adelarue/SchoolBusRouting.git")
```
Alternatively, you can just copy (or `git clone`) the repository in `~/.julia/v0.6/`, which is automatically created when Julia 0.6 is installed.

Once the `SchoolBusRouting` directory is in the `~/julia/v0.6` directory, you can run `Pkg.resolve()` to install all open-source dependencies (or install them manually using `Pkg.add()`). Note that in order to use the package, you must have Gurobi and an appropriate license installed on your machine. Instructions on obtaining Gurobi and an academic license can be found at https://www.gurobi.com/downloads/download-center

Reproducing the results from the article can be done by running the code in `examples/pnas.jl`.

Authors: Arthur Delarue, Sebastien Martin

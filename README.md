# SchoolBusRouting

This is a simple Julia package to reproduce our school bus routing results on synthetic benchmarks from Park, Tae and Kim (2011). To use the package, you will need to have Julia 0.6 installed on your machine.

You can then download the package by running the following command in the Julia REPL:
```julia
julia> Pkg.clone("https://github.com/adelarue/SchoolBusRouting.git")
```
Alternatively, you can just copy (or `git clone`) the repository in `~/.julia/v0.6/`, which is automatically created when Julia 0.6 is installed.

Once the `SchoolBusRouting` directory is in the `~/julia/v0.6` directory, you can run `Pkg.resolve()` to install all open-source dependencies (or install them manually using `Pkg.add()`). Note that in order to use the package, you must have Gurobi and an appropriate license installed on your machine. Instructions on obtaining Gurobi and an academic license can be found at https://www.gurobi.com/downloads/download-center

Reproducing the results from the submitted article can be done by running the code in `examples/pnas-tableS1.jl` and `examples/pnas-tableS2.jl`, e.g. by running 
```bash
julia examples/pnas-tableS1.jl
```
from the command line, or alternatively opening julia's command prompt and running
```julia
julia> include("examples/pnas-tableS1.jl")
```

For more details about the output of these scripts, check out `docs/output-pnas.md`

As part of this package, we also provide code to generate synthetic benchmarks for future studies. Details can be found in `docs/benchmarks.md`.

We also provide a way to graphically visualize school bus routing problems and solutions. See `docs/visualization.md` for more details.

If you use any of this code in your research, please cite our article!

Authors: Dimitris Bertsimas, Arthur Delarue, Sebastien Martin

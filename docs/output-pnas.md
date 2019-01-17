# Understanding PNAS output

The files `examples/pnas-tableS1.jl` and `examples/pnas-tableS2.jl` produce several forms of output.

- They create the files `output/pnas-tableS1.csv` and `output/pnas-tableS2.csv`, which contain the number of buses obtained for each experiment. We provide some R code in `output/pnas-tables.R` to help manipulate these files. They are also human-readable.

- Each school bus routing solution is output as a human-readable ASCII file and a machine-readable JLD file. These files are saved in `output/tableS1` and `output/tableS2` respectively. Each experiment has a unique experiment id `i` which indexes the ASCII output as `solution-(i).csv` and the JLD output as `solution-(i).jld`. The experiment id can be mapped to the experiment parameters using the master tables described in the previous bullet.

The JLD files can be loaded in Julia in the following way
```julia
julia> using SchoolBusRouting, JLD

julia> cd("$(Pkg.dir("SchoolBusRouting"))/output/tableS1") # navigate to directory

julia> data = JLD.load("solution-1.jld", "data") # replace 1 with the desired id

julia> SchoolBusRouting.test(data) # feasibility check routine
```

From there, it can be verified that the JLD and ASCII files are indeed equivalent by outputting the saved data object to a dataframe, and then writing this dataframe to :

```julia
julia> using CSV

julia> out = SchoolBusRouting.output(data)

julia> CSV.write("test_file.csv", out) # or some other file name
```

The output CSV file has 6 columns. Each row corresponds to a transition from one location to another (possibly the same if the bus is just waiting in the same location). The columns are:
- Bus id
- Start location
- End location
- Action: what happens between these two locations. Possible values are "deadhead" (empty travel), "travel", "pickup", "dropoff", and "wait"
- Time at start location
- Time at end location


###################################################
## SchoolBusRouting.jl
##      Module root
## Authors: Arthur Delarue, Sébastien Martin, 2018
###################################################

module SchoolBusRouting

using DataFrames, CSV
using LightGraphs, NearestNeighbors, ProgressMeter
using Geodesy, Colors
using JuMP, Gurobi
import JLD
import Base: convert

include("problem.jl")
include("load.jl")
include("scenarios.jl")
include("selection.jl")

end
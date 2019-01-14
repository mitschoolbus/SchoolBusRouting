###################################################
## SchoolBusRouting.jl
##      Module root
## Authors: Arthur Delarue, Sébastien Martin, 2018
###################################################

module SBR

using DataFrames, CSV
using LightGraphs, NearestNeighbors, ProgressMeter
using Geodesy, Colors
using JuMP, Gurobi
import JLD
import Base: convert
using SFML, Plots

include("problem.jl")
include("load.jl")
include("scenarios.jl")
include("selection.jl")
include("tests.jl")
include("output.jl")
include("lbh.jl")
include("viz.jl")
include("synthetic.jl")

end
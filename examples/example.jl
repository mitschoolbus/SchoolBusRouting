###################################################
## example.jl
##     Using SchoolBusRouting code
## Authors: Arthur Delarue, Sébastien Martin, 2018
###################################################

using SchoolBusRouting, JLD

PATH = "/Users/arthurdelarue/Dropbox\ (MIT)/SchoolBuses/Data/Synthetic-benchmarks/SBRP_Benchmark";
data = SchoolBusRouting.loadSyntheticBenchmark("$PATH/RSRB/RSRB03/schools.txt",
                                               "$PATH/RSRB/RSRB03/stops.txt",
                                               spreadStart = true, maxEffect=5000.);
#data = JLD.load("$PATH/Data/RSRB03-2700.0.jld", "data")

data.params.max_time_on_bus = 2700.;
λs = [1e2, 5e2, 5e3, 1e4, 5e4, 1e5];
params = [SchoolBusRouting.ScenarioParameters(maxRouteTimeLower=2000, maxRouteTimeUpper=5000,
                                              nGreedy=20, λ=λ, nIterations=80) for λ in λs];
scenariolist = SchoolBusRouting.computescenarios(data, params);
SchoolBusRouting.loadroutingscenarios!(data, scenariolist);

SchoolBusRouting.routeBuses!(data);
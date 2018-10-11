###################################################
## pnas.jl
##     Run simulations for PNAS article
## Authors: Arthur Delarue, Sébastien Martin, 2018
###################################################

using SchoolBusRouting, JLD

RSRB = ["RSRB0$i" for i = 1:8];
CSCB = [@sprintf("CSCB%02d", i) for i = 1:16];
experiments = vcat(RSRB, CSCB);
maxtimes = [2700.0, 5400.0];

for maxtime in maxtimes, experiment in experiments
    PATH = string(Pkg.dir("SchoolBusRouting"), "/data");
    data = JLD.load("$PATH/$experiment-$maxtime.jld", "data")

    data.params.max_time_on_bus = maxtime;
    λs = [1e2, 5e2, 5e3, 1e4, 5e4, 1e5, 5e5];
    if maxtime < 3000
        params = [SchoolBusRouting.ScenarioParameters(maxRouteTimeLower=2000,
                                                      maxRouteTimeUpper=5000,
                                                      nGreedy=20, λ=λ, nIterations=80) for λ in λs];
    else
        params = [SchoolBusRouting.ScenarioParameters(maxRouteTimeLower=2000,
                                                      maxRouteTimeUpper=7000,
                                                      nGreedy=20, λ=λ, nIterations=80) for λ in λs];
    end
    bestBuses = Inf
    # random restarts
    for i = 1:3
        srand(i)
        scenariolist = SchoolBusRouting.computescenarios(data, params);
        SchoolBusRouting.loadroutingscenarios!(data, scenariolist);
        SchoolBusRouting.routeBuses!(data, OutputFlag=0);
        if length(data.buses) < bestBuses
            bestBuses = length(data.buses)
            # test feasibility as a sanity check
            SchoolBusRouting.test(data)
    	end
    end
    println("$experiment\t$maxtime\t$bestBuses buses")
end

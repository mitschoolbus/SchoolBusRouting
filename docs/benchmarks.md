# Using the code to generate synthetic benchmarks

Part of the SchoolBusRouting package is the generation of synthetic benchmarks.

They can be generated with the function `SchoolBusRouting.syntheticproblem`

Parameters:
- nschools: the number of schools (Int)
- nyards: the number of depots (Int)
- districtsize: the length in meters of an edge of the district (it is a square) (Float)
- dwelltime: the amount of time buses must wait at a school before they become available for the next route (Float)
- studentsperschool: the number of students per school (Int)
- schoolrange: the minimum and maximum distance between a student and a school (Tuple{Float, Float})
- studentspread: governs how spread out the students are for one school (Float)
- studentclustering: the probability that each student has of being generated close to other students (Float)
- maxwalking: the maximum walking distance to a stop (Float) in meters
- d2dfraction: the fraction of students that require their own stop and must be picked up from their home

More details regarding these parameters are available in the paper.

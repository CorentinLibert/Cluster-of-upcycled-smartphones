# NPF Benchmark: All steps

This document contains all steps done by the benchmark in order to mesure the performances of the smartphone cluster for a TensorFlow Lite application of images classification.

## Setup

We will use NPF with the module `wrk2tbarbette` to perform tests on **close loop**, send the maximum requests and see what can be answered. This can be done thanks to `wrk2` and its rate functionnality.

## Steps

I used the version of `wrk2` of Tom Barbette. Update the module `wrk2` from modules to match my requirements. Value can still be changed. For the moment the module is simply called from a `.npf` script as it. Should pass some variable (but how?). Should add CPU and Memory usage. Should work around the `wrk` script to use it from NPF (cf. paths). 

## What will be done now

- [] NPF script: 
    - Add a loop with `%variables` in order to change execute the script for a certain number of replicas.
    - Add a script that will change the number of replica in the cluster.
    - Add some sleep time in order to make each test from `wrk` independant from the previous one.
- [] Bash script:
    - Create a bash script that will retrieve the CPU and Memory usage from each smartphone.
    - Should be called in the NPF script (in order to retrieve the values during execution).
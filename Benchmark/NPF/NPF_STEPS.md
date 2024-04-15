# NPF Benchmark: All steps

This document contains all steps done by the benchmark in order to mesure the performances of the smartphone cluster for a TensorFlow Lite application of images classification.

## Setup

We will use NPF with the module `wrk2tbarbette` to perform tests on **close loop**, send the maximum requests and see what can be answered. This can be done thanks to `wrk2` and its rate functionnality.

## Steps

I used the version of `wrk2` of Tom Barbette. Update the module `wrk2` from modules to match my requirements. Value can still be changed. For the moment the module is simply called from a `.npf` script as it. Should pass some variable (but how?). Should add CPU and Memory usage. Should work around the `wrk` script to use it from NPF (cf. paths). 
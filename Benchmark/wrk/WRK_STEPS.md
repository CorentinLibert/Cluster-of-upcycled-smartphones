# WRK: All steps

This file contains all steps followed to test if `wrk` is working good with the smartphones.

## Simple setup without `wrk`

I first checked with only one smartphone connected per USB to my computer.
I made the `Flask` application run outside of any framework (not in `Docker` nor in `k3s`) for more ease in testing on LLN.
To make the application run use the following command in the same directory than the `app.py` (of `Flask`).

```bash
flask run --host=172.16.42.1
```

Where `172.16.42.1` is the ip address of the smartphone (here through USB).

Then check if the `Flask` application is reachable from outside, for example by running the following command on you PC from the directory containing the bitmap `grace_hopper.bmp`.

```bash
curl -X POST -F "image=@grace_hopper.bmp" http://172.16.42.1:5000
```

Where `172.16.42.1:5000` are the ip and port from which the `Flask` application is listenning.

## Adding `wrk`

You can run the script [simple_script.lua](simple_script.lua) which will create HTTP POST request containing the bitmap [grace_hopper.bmp](grace_hopper.bmp). It will also log all response in a file name `wrk.log`. Here is an example of a command to run it from the [wrk directory](../wrk/).

```bash
wrk -c1 -d5s -t1 -s new_simple_script.lua http://172.16.42.1:5000
```
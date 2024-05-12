# K3S troubleshooting on smartphones

This file contains all troubleshooting while installing K3S on smartphones under postmarketOS.

## CONFIG_NETFILTER_XT_MATCH_MULTIPORT: missing (fail)

The kernel modeul NETFILTER_XT_MATCH_MULTIPORT is missing on smartphone. At least K3S does not see it. It is needed for Traefik, the Loadbalancer Service. Without it the pods for traefik are stuck in ContainerCreating.
What's strange is that it seems like smartphones can still balance the load between them...

It results in problems when the server is a computer, since the module start on it. The smartphone agents cannot connect to it since Traefik fails.


```
fp2xcvr17:/lib/modules/6.7.0-postmarketos-qcom-msm8974/kernel/net/netfilter$ 
```
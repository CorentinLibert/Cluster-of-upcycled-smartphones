# Complete K3S tutorial

## Requirement

On a smartphone that has just been flashed:
- Connect to Wi-Fi
- Resolve date problem (if there is any): `sudo touch /etc/network/interfaces`
- Install curl `sudo apk add curl`

## Simple server with an agent

Run the default command:

```bash
curl -sfL https://get.k3s.io | sh -
```


## Expose a deployment outside the cluter

We can expose a deployment outside the cluster using the following command:

```bash
kubectl expose deployment nginx-deployment --type=LoadBalancer --name=bla --external-ip=192.168.88.4 --port=80
```

The next step is to expose it using a service and a loadbalancer ([see documentation](https://kubernetes.io/docs/tutorials/kubernetes-basics/expose/expose-intro/))


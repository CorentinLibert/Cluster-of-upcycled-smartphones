# Complete K3S tutorial

## Requirement

On a smartphone that has just been flashed:
- Connect to Wi-Fi
- Resolve date problem (if there is any): `sudo touch /etc/network/interfaces`
- Install curl `sudo apk add curl`

## Create a simple server

Run the default command:

```bash
curl -sfL https://get.k3s.io | sh -
```

After some time, verify the installation with:

```bash
kubectl get nodes
```

## Connect a simple agent to the server

First, connect on the server and retrieve the **server node token**:

```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```

Then, on the agent, connect to the server:

```bash
curl -sfL https://get.k3s.io | K3S_URL=https://myserver:6443 K3S_TOKEN=mynodetoken sh -
```

## Application deployement

### Import image from .tar (manually)

Copy the `tar` archive on the node, then run:

```
sudo k3s ctr images import <image-name.tar>
```

## Expose a deployment outside the cluter

We can expose a deployment outside the cluster using the following command:

```bash
kubectl expose deployment nginx-deployment --type=LoadBalancer --name=bla --external-ip=192.168.88.4 --port=80
```

The next step is to expose it using a service and a loadbalancer ([see documentation](https://kubernetes.io/docs/tutorials/kubernetes-basics/expose/expose-intro/))


## Uninstall K3S and K3S-agent

To uninstall a **k3s server**:

```bash
sudo /usr/local/bin/k3s-uninstall.sh
```

To uninstall a **k3s agent**:

```bash
sudo /usr/local/bin/k3s-agent-uninstall.sh
```
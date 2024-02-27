# How to setup a k3s cluster on the smartphones.

## Installations:

First download the `k3s` apk package:

```bash
sudo apk udpate
sudo apk add k3s
```

<!-- Not working if no control plane 

You can verify the installation by running `sudo kubectl get nodes`. It should show you something like:

```bash
NAME       STATUS   ROLES                  AGE     VERSION
fp2xcvr2   Ready    control-plane,master   7m45s   v1.29.1-k3s1
``` -->

## Setup:

We will based our setup installation on [this video](https://www.youtube.com/watch?v=QDwhbMvikGQ). 

First we will configure the **load balancer node**.

### Setting up the server

This command seems to be working:

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644 --tls-san 192.168.88.3 --node-external-ip 192.168.88.3" sh -s -
```

but not this one:

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644 --disable traefik --tls-san 192.168.88.3 --node-external-ip 192.168.88.3 --disable servicelb" sh -s -
```

I need to check if it is because i disabled `traefik` or because I disabled `servicelb`?
I need to check how I can setup a load balancer different from `traefik`.

### Setting up the workers

This command works to setup the client: 

```bash
curl -sfL https://get.k3s.io | sh -s - agent --server https://192.168.88.3:6443 --token K10aa1780b63524f7fede574293c6d800b03e21797b8d5dd6e3f432c87ac5b2a4e9::server:7d2ac36c67f3ecdac960cf8c878d9966
```

### Load balancer node

We will first need to setup a load balancer using a reverse proxy server. You may use `nginx` or `HAProxy`. For HA cluster, `HAProxy` is way better.


#### Nginx installation

**WARNING:** As per the [k3s documentation](https://docs.k3s.io/datastore/cluster-loadbalancer), `nginx`is not suitable for HA cluster. Having a single load balancer in front of K3s will reintroduce a single point of failure. In this tutorial we will still use it, but it would be better to use something else later (e.g. `HAProxy`).

We will have to install `nginx`, an HTTP and reverse proxy server, a mail proxy server, and a generic TCP/UDP proxy server.
We will also need to install its stream module:

```bash
sudo apk update
sudo apk add nginx
sudo apk add nginx-mod-stream
```

Once install, you can rename the current config in `/etc/nginx/` as `nginx.conf.bk` (in order to not delete it, if needed afterwards), and create the following new `nginx.config`:

```                                                                         
load_module '/usr/lib/nginx/modules/ngx_stream_module.so';

worker_processes auto;
worker_rlimit_nofile 40000;

events {
  worker_connections 8192;
}

stream {
  upstream k3s_server {
    server 192.168.88.3:6443 max_fails=3 fail_timeout=5s;
  }

  server {
    listen 6443;
    proxy_pass k3s_server;
  }
}
```

You can test it with `sudo nginx -t`. You can run the `nginx` service with `sudo rc-service nginx start`.


## Problems:

### Unable to install `k3s` after uninstalling it

You may struggle to reinstall the `k3s` apk package after uninstalling it and have the following errors:

```bash
(1/2) Installing k3s (1.29.1.1-r1)
ERROR: Failed to create usr/bin/k3s: Connection aborted
ERROR: k3s-1.29.1.1-r1: BAD signature
(2/2) Installing k3s-openrc (1.29.1.1-r1)
ERROR: k3s-openrc-1.29.1.1-r1: BAD signature
2 errors; 589 MiB in 255 packages
```

The solution is to remove all file/folder containing `k3s` in their name. You can find them with `sudo find / -name "*k3s*"`. After that:

```bash
sudo apk update
sudo apkt add k3s
```

### Date stuck on 01/01/1970

The system date may be stuck on the 01/01/1970, you can see it with the command `date`. This can lead to problem such as the impossibility to use `curl`. One way to solve this issue is to install et start a _NTP client package_, for example `chrony`.

```bash
sudo apk update
sudo apk add chrony
sudo rc-service chronyd start
```

To ensure it runs automatically at boot:
```bash
rc-update add chronyd default
```

This should solve the problem. Check with `date`.

**UPDATE:** You do not need to download `chrony`, you may just start the ntpd service: `sudo rc-service ntpd start`.

### DNS problem

When running `kubectl get nodes`, you will encounter an error to access the server:

```bash
E0101 10:44:52.076856    7818 memcache.go:265] couldn't get current server API group list: Get "http://localhost:8080/api?timeout=32s": dial tcp [::1]:8080: connect: connection refused
E0101 10:44:52.081254    7818 memcache.go:265] couldn't get current server API group list: Get "http://localhost:8080/api?timeout=32s": dial tcp [::1]:8080: connect: connection refused
E0101 10:44:52.084757    7818 memcache.go:265] couldn't get current server API group list: Get "http://localhost:8080/api?timeout=32s": dial tcp [::1]:8080: connect: connection refused
E0101 10:44:52.088151    7818 memcache.go:265] couldn't get current server API group list: Get "http://localhost:8080/api?timeout=32s": dial tcp [::1]:8080: connect: connection refused
E0101 10:44:52.091585    7818 memcache.go:265] couldn't get current server API group list: Get "http://localhost:8080/api?timeout=32s": dial tcp [::1]:8080: connect: connection refused
The connection to the server localhost:8080 was refused - did you specify the right host or port?
```

You may have more information running `kubectl get nodes -v=10`:

```bash
I0101 10:45:41.990318    7903 round_trippers.go:466] curl -v -XGET  -H "Accept: application/json;g=apidiscovery.k8s.io;v=v2beta1;as=APIGroupDiscoveryList,application/json" -H "User-Agent: kubectl/v1.29.1 (linux/arm) kubernetes/6156126" 'http://localhost:8080/api?timeout=32s'
I0101 10:45:41.993471    7903 round_trippers.go:495] HTTP Trace: DNS Lookup for localhost resolved to [{::1 } {127.0.0.1 }]
I0101 10:45:41.994368    7903 round_trippers.go:508] HTTP Trace: Dial to tcp:[::1]:8080 failed: dial tcp [::1]:8080: connect: connection refused
I0101 10:45:41.995140    7903 round_trippers.go:508] HTTP Trace: Dial to tcp:127.0.0.1:8080 failed: dial tcp 127.0.0.1:8080: connect: connection refused
I0101 10:45:41.995490    7903 round_trippers.go:553] GET http://localhost:8080/api?timeout=32s  in 4 milliseconds
I0101 10:45:41.995668    7903 round_trippers.go:570] HTTP Statistics: DNSLookup 0 ms Dial 0 ms TLSHandshake 0 ms Duration 4 ms
I0101 10:45:41.995822    7903 round_trippers.go:577] Response Headers:
E0101 10:45:41.996982    7903 memcache.go:265] couldn't get current server API group list: Get "http://localhost:8080/api?timeout=32s": dial tcp [::1]:8080: connect: connection refused
I0101 10:45:41.997410    7903 cached_discovery.go:120] skipped caching discovery info due to Get "http://localhost:8080/api?timeout=32s": dial tcp [::1]:8080: connect: connection refused
I0101 10:45:41.998468    7903 round_trippers.go:466] curl -v -XGET  -H "User-Agent: kubectl/v1.29.1 (linux/arm) kubernetes/6156126" -H "Accept: application/json;g=apidiscovery.k8s.io;v=v2beta1;as=APIGroupDiscoveryList,application/json" 'http://localhost:8080/api?timeout=32s'
I0101 10:45:41.999677    7903 round_trippers.go:495] HTTP Trace: DNS Lookup for localhost resolved to [{::1 } {127.0.0.1 }]
I0101 10:45:42.000413    7903 round_trippers.go:508] HTTP Trace: Dial to tcp:[::1]:8080 failed: dial tcp [::1]:8080: connect: connection refused
I0101 10:45:42.001383    7903 round_trippers.go:508] HTTP Trace: Dial to tcp:127.0.0.1:8080 failed: dial tcp 127.0.0.1:8080: connect: connection refused
I0101 10:45:42.001749    7903 round_trippers.go:553] GET http://localhost:8080/api?timeout=32s  in 3 milliseconds
I0101 10:45:42.001929    7903 round_trippers.go:570] HTTP Statistics: DNSLookup 0 ms Dial 0 ms TLSHandshake 0 ms Duration 3 ms
I0101 10:45:42.002075    7903 round_trippers.go:577] Response Headers:
E0101 10:45:42.002582    7903 memcache.go:265] couldn't get current server API group list: Get "http://localhost:8080/api?timeout=32s": dial tcp [::1]:8080: connect: connection refused
I0101 10:45:42.002742    7903 cached_discovery.go:120] skipped caching discovery info due to Get "http://localhost:8080/api?timeout=32s": dial tcp [::1]:8080: connect: connection refused
I0101 10:45:42.002902    7903 shortcut.go:103] Error loading discovery information: Get "http://localhost:8080/api?timeout=32s": dial tcp [::1]:8080: connect: connection refused
I0101 10:45:42.003803    7903 round_trippers.go:466] curl -v -XGET  -H "Accept: application/json;g=apidiscovery.k8s.io;v=v2beta1;as=APIGroupDiscoveryList,application/json" -H "User-Agent: kubectl/v1.29.1 (linux/arm) kubernetes/6156126" 'http://localhost:8080/api?timeout=32s'
I0101 10:45:42.005288    7903 round_trippers.go:495] HTTP Trace: DNS Lookup for localhost resolved to [{::1 } {127.0.0.1 }]
I0101 10:45:42.006186    7903 round_trippers.go:508] HTTP Trace: Dial to tcp:[::1]:8080 failed: dial tcp [::1]:8080: connect: connection refused
I0101 10:45:42.007107    7903 round_trippers.go:508] HTTP Trace: Dial to tcp:127.0.0.1:8080 failed: dial tcp 127.0.0.1:8080: connect: connection refused
I0101 10:45:42.007423    7903 round_trippers.go:553] GET http://localhost:8080/api?timeout=32s  in 3 milliseconds
I0101 10:45:42.007596    7903 round_trippers.go:570] HTTP Statistics: DNSLookup 0 ms Dial 0 ms TLSHandshake 0 ms Duration 3 ms
I0101 10:45:42.007742    7903 round_trippers.go:577] Response Headers:
E0101 10:45:42.008216    7903 memcache.go:265] couldn't get current server API group list: Get "http://localhost:8080/api?timeout=32s": dial tcp [::1]:8080: connect: connection refused
I0101 10:45:42.008370    7903 cached_discovery.go:120] skipped caching discovery info due to Get "http://localhost:8080/api?timeout=32s": dial tcp [::1]:8080: connect: connection refused
I0101 10:45:42.009246    7903 round_trippers.go:466] curl -v -XGET  -H "Accept: application/json;g=apidiscovery.k8s.io;v=v2beta1;as=APIGroupDiscoveryList,application/json" -H "User-Agent: kubectl/v1.29.1 (linux/arm) kubernetes/6156126" 'http://localhost:8080/api?timeout=32s'
I0101 10:45:42.010643    7903 round_trippers.go:495] HTTP Trace: DNS Lookup for localhost resolved to [{::1 } {127.0.0.1 }]
I0101 10:45:42.011510    7903 round_trippers.go:508] HTTP Trace: Dial to tcp:[::1]:8080 failed: dial tcp [::1]:8080: connect: connection refused
I0101 10:45:42.012931    7903 round_trippers.go:508] HTTP Trace: Dial to tcp:127.0.0.1:8080 failed: dial tcp 127.0.0.1:8080: connect: connection refused
I0101 10:45:42.013313    7903 round_trippers.go:553] GET http://localhost:8080/api?timeout=32s  in 3 milliseconds
I0101 10:45:42.013466    7903 round_trippers.go:570] HTTP Statistics: DNSLookup 0 ms Dial 0 ms TLSHandshake 0 ms Duration 3 ms
I0101 10:45:42.013593    7903 round_trippers.go:577] Response Headers:
E0101 10:45:42.014094    7903 memcache.go:265] couldn't get current server API group list: Get "http://localhost:8080/api?timeout=32s": dial tcp [::1]:8080: connect: connection refused
I0101 10:45:42.014248    7903 cached_discovery.go:120] skipped caching discovery info due to Get "http://localhost:8080/api?timeout=32s": dial tcp [::1]:8080: connect: connection refused
I0101 10:45:42.015025    7903 round_trippers.go:466] curl -v -XGET  -H "User-Agent: kubectl/v1.29.1 (linux/arm) kubernetes/6156126" -H "Accept: application/json;g=apidiscovery.k8s.io;v=v2beta1;as=APIGroupDiscoveryList,application/json" 'http://localhost:8080/api?timeout=32s'
I0101 10:45:42.016533    7903 round_trippers.go:495] HTTP Trace: DNS Lookup for localhost resolved to [{::1 } {127.0.0.1 }]
I0101 10:45:42.017459    7903 round_trippers.go:508] HTTP Trace: Dial to tcp:[::1]:8080 failed: dial tcp [::1]:8080: connect: connection refused
I0101 10:45:42.018569    7903 round_trippers.go:508] HTTP Trace: Dial to tcp:127.0.0.1:8080 failed: dial tcp 127.0.0.1:8080: connect: connection refused
I0101 10:45:42.019106    7903 round_trippers.go:553] GET http://localhost:8080/api?timeout=32s  in 3 milliseconds
I0101 10:45:42.019949    7903 round_trippers.go:570] HTTP Statistics: DNSLookup 0 ms Dial 0 ms TLSHandshake 0 ms Duration 3 ms
I0101 10:45:42.020331    7903 round_trippers.go:577] Response Headers:
E0101 10:45:42.021214    7903 memcache.go:265] couldn't get current server API group list: Get "http://localhost:8080/api?timeout=32s": dial tcp [::1]:8080: connect: connection refused
I0101 10:45:42.021656    7903 cached_discovery.go:120] skipped caching discovery info due to Get "http://localhost:8080/api?timeout=32s": dial tcp [::1]:8080: connect: connection refused
I0101 10:45:42.022495    7903 helpers.go:264] Connection error: Get http://localhost:8080/api?timeout=32s: dial tcp [::1]:8080: connect: connection refused
The connection to the server localhost:8080 was refused - did you specify the right host or port?
```

Apparently, this is because `kubectl` can't find a cluster information to connect to. The solution is to either configure a cluster manually or install `minikube` which will configure a single cluser node using any hypervisor or docker (cf. [this stackoverflow issue](https://stackoverflow.com/questions/76841889/kubectl-error-memcache-go265-couldn-t-get-current-server-api-group-list-get)).

SOLUTION: It seems like the real problem came from the wrong date (see [Date stuck on 01/01/1970](#date-stuck-on-01011970)). Changing the `date` back to the current one changed the error to:

```bash
WARN[0001] Unable to read /etc/rancher/k3s/k3s.yaml, please start server with --write-kubeconfig-mode to modify kube config permissions 
error: error loading config file "/etc/rancher/k3s/k3s.yaml": open /etc/rancher/k3s/k3s.yaml: permission denied
```

And this is simply because I was not executing the command with the privileges: 

```bash
sudo kubectl get nodes
```

### Could not connect agent to server: Could not connect to proxy

While running `sudo k3s agent -t K10a11aca070d38fee155c5152f60a13e27cf582094bc76d0a171e260208b30945c::server:1d95f2c1219c0361165b4d9e5d572518 --server https://192.168.88.247:6443 
`

Got: 
```bash
INFO[0001] Starting k3s agent v1.28.6+k3s2 (c9f49a3b)   
INFO[0001] Adding server to load balancer k3s-agent-load-balancer: 192.168.88.247:6443 
INFO[0001] Running load balancer k3s-agent-load-balancer 127.0.0.1:6444 -> [192.168.88.247:6443] [default: 192.168.88.247:6443] 
INFO[0015] Module overlay was already loaded            
W0225 02:05:04.151658    3896 sysinfo.go:203] Nodes topology is not available, providing CPU topology
INFO[0015] Set sysctl 'net/netfilter/nf_conntrack_tcp_timeout_close_wait' to 3600 
INFO[0015] Set sysctl 'net/ipv4/conf/all/forwarding' to 1 
INFO[0015] Set sysctl 'net/netfilter/nf_conntrack_max' to 131072 
INFO[0015] Set sysctl 'net/netfilter/nf_conntrack_tcp_timeout_established' to 86400 
INFO[0015] Logging containerd to /var/lib/rancher/k3s/agent/containerd/containerd.log 
INFO[0015] Running containerd -c /var/lib/rancher/k3s/agent/etc/containerd/config.toml -a /run/k3s/containerd/containerd.sock --state /run/k3s/containerd --root /var/lib/rancher/k3s/agent/containerd 
INFO[0016] Waiting for containerd startup: rpc error: code = Unavailable desc = connection error: desc = "transport: Error while dialing: dial unix /run/k3s/containerd/containerd.sock: connect: no such file or directory" 
INFO[0017] Waiting for containerd startup: rpc error: code = Unavailable desc = connection error: desc = "transport: Error while dialing: dial unix /run/k3s/containerd/containerd.sock: connect: no such file or directory" 
INFO[0019] containerd is now running                    
INFO[0019] Getting list of apiserver endpoints from server 
INFO[0020] Updated load balancer k3s-agent-load-balancer default server address -> 192.168.1.109:6443 
INFO[0020] Adding server to load balancer k3s-agent-load-balancer: 192.168.1.109:6443 
INFO[0020] Removing server from load balancer k3s-agent-load-balancer: 192.168.88.247:6443 
INFO[0020] Updated load balancer k3s-agent-load-balancer server addresses -> [192.168.1.109:6443] [default: 192.168.1.109:6443] 
INFO[0020] Connecting to proxy                           url="wss://192.168.1.109:6443/v1-k3s/connect"
INFO[0020] Running kubelet --address=0.0.0.0 --allowed-unsafe-sysctls=net.ipv4.ip_forward,net.ipv6.conf.all.forwarding --anonymous-auth=false --authentication-token-webhook=true --authorization-mode=Webhook --cgroup-driver=cgroupfs --client-ca-file=/var/lib/rancher/k3s/agent/client-ca.crt --cloud-provider=external --cluster-dns=10.43.0.10 --cluster-domain=cluster.local --container-runtime-endpoint=unix:///run/k3s/containerd/containerd.sock --containerd=/run/k3s/containerd/containerd.sock --eviction-hard=imagefs.available<5%,nodefs.available<5% --eviction-minimum-reclaim=imagefs.available=10%,nodefs.available=10% --fail-swap-on=false --feature-gates=CloudDualStackNodeIPs=true --healthz-bind-address=127.0.0.1 --hostname-override=fp2xcvr4 --kubeconfig=/var/lib/rancher/k3s/agent/kubelet.kubeconfig --node-ip=192.168.88.250 --node-labels= --pod-infra-container-image=rancher/mirrored-pause:3.6 --pod-manifest-path=/var/lib/rancher/k3s/agent/pod-manifests --read-only-port=0 --resolv-conf=/etc/resolv.conf --serialize-image-pulls=false --tls-cert-file=/var/lib/rancher/k3s/agent/serving-kubelet.crt --tls-private-key-file=/var/lib/rancher/k3s/agent/serving-kubelet.key 
ERRO[0023] Failed to connect to proxy. Empty dialer response  error="dial tcp 192.168.1.109:6443: connect: no route to host"
ERRO[0023] Remotedialer proxy error                      error="dial tcp 192.168.1.109:6443: connect: no route to host"
INFO[0026] Waiting to retrieve kube-proxy configuration; server is not ready: failed to get CA certs: Get "https://127.0.0.1:6444/cacerts": read tcp 127.0.0.1:39534->127.0.0.1:6444: read: connection reset by peer 
INFO[0028] Connecting to proxy                           url="wss://192.168.1.109:6443/v1-k3s/connect"
ERRO[0029] Failed to connect to proxy. Empty dialer response  error="dial tcp 192.168.1.109:6443: connect: no route to host"
ERRO[0029] Remotedialer proxy error                      error="dial tcp 192.168.1.109:6443: connect: no route to host"
INFO[0034] Connecting to proxy                           url="wss://192.168.1.109:6443/v1-k3s/connect"
ERRO[0035] Failed to connect to proxy. Empty dialer response  error="dial tcp 192.168.1.109:6443: connect: no route to host"
ERRO[0035] Remotedialer proxy error                      error="dial tcp 192.168.1.109:6443: connect: no route to host"
INFO[0035] Waiting to retrieve kube-proxy configuration; server is not ready: failed to get CA certs: Get "https://127.0.0.1:6444/cacerts": read tcp 127.0.0.1:42862->127.0.0.1:6444: read: connection reset by peer 
INFO[0040] Connecting to proxy                           url="wss://192.168.1.109:6443/v1-k3s/connect"
ERRO[0041] Failed to connect to proxy. Empty dialer response  error="dial tcp 192.168.1.109:6443: connect: no route to host"
ERRO[0041] Remotedialer proxy error                      error="dial tcp 192.168.1.109:6443: connect: no route to host"
INFO[0041] Waiting to retrieve kube-proxy configuration; server is not ready: failed to get CA certs: Get "https://127.0.0.1:6444/cacerts": read tcp 127.0.0.1:42946->127.0.0.1:6444: read: connection reset by peer 
INFO[0046] Connecting to proxy                           url="wss://192.168.1.109:6443/v1-k3s/connect"
ERRO[0048] Failed to connect to proxy. Empty dialer response  error="dial tcp 192.168.1.109:6443: connect: no route to host"
ERRO[0048] Remotedialer proxy error                      error="dial tcp 192.168.1.109:6443: connect: no route to host"
INFO[0051] Waiting to retrieve kube-proxy configuration; server is not ready: failed to get CA certs: Get "https://127.0.0.1:6444/cacerts": read tcp 127.0.0.1:35824->127.0.0.1:6444: read: connection reset by peer 
INFO[0053] Connecting to proxy                           url="wss://192.168.1.109:6443/v1-k3s/connect"
ERRO[0054] Failed to connect to proxy. Empty dialer response  error="dial tcp 192.168.1.109:6443: connect: no route to host"
ERRO[0054] Remotedialer proxy error                      error="dial tcp 192.168.1.109:6443: connect: no route to host"
W0225 02:05:42.533182    3896 reflector.go:535] k8s.io/client-go@v1.28.6-k3s1/tools/cache/reflector.go:229: failed to list *v1.Endpoints: Get "https://127.0.0.1:6444/api/v1/namespaces/default/endpoints?fieldSelector=metadata.name%3Dkubernetes&limit=500&resourceVersion=0": read tcp 127.0.0.1:55314->127.0.0.1:6444: read: connection reset by peer - error from a previous attempt: read tcp 127.0.0.1:35840->127.0.0.1:6444: read: connection reset by peer
I0225 02:05:42.533890    3896 trace.go:236] Trace[947078016]: "Reflector ListAndWatch" name:k8s.io/client-go@v1.28.6-k3s1/tools/cache/reflector.go:229 (25-Feb-2024 02:05:09.012) (total time: 33520ms):
Trace[947078016]: ---"Objects listed" error:Get "https://127.0.0.1:6444/api/v1/namespaces/default/endpoints?fieldSelector=metadata.name%3Dkubernetes&limit=500&resourceVersion=0": read tcp 127.0.0.1:55314->127.0.0.1:6444: read: connection reset by peer - error from a previous attempt: read tcp 127.0.0.1:35840->127.0.0.1:6444: read: connection reset by peer 33520ms (02:05:42.533)
Trace[947078016]: [33.520581485s] [33.520581485s] END
E0225 02:05:42.534308    3896 reflector.go:147] k8s.io/client-go@v1.28.6-k3s1/tools/cache/reflector.go:229: Failed to watch *v1.Endpoints: failed to list *v1.Endpoints: Get "https://127.0.0.1:6444/api/v1/namespaces/default/endpoints?fieldSelector=metadata.name%3Dkubernetes&limit=500&resourceVersion=0": read tcp 127.0.0.1:55314->127.0.0.1:6444: read: connection reset by peer - error from a previous attempt: read tcp 127.0.0.1:35840->127.0.0.1:6444: read: connection reset by peer
```

Not resolved yet.
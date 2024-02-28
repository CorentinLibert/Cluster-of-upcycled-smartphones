# TFE planning

Start: 16/02
End: 17/03

## Issues

- [ ] On smartphone 4: NTPD is down and corrupted du to a `sudo apk add --force ntp`.. Have to reoslve this

## Things TODO

- [ ] Implement a distributed application as an use case
	- [ ] Kubernetes (K3S) on smartphones
		- [ ] Check how does the load balancer works? What it does? Is it a real load balancer for the external load or only for internal traffic btw agent and server.
	- [ ] Docker swarm on smartphones
		- Is it better to use k3S or 
	- [ ] TFlite model for object detection
- [ ] Measurements
	- [ ] Wi-Fi: Limitations, see corner cases (Max smartphones, Types of applications that can be run on it).
	- [ ] Ethernet: Limitations, see corner cases (Max smartphones, Types of applications that can be run on it).
	- [ ] Hybrid: Mix between Wi-Fi and Ethernet: Limitations, see corner cases (Max smartphones, Types of applications that can be run on it).
	- [ ] USB 2.0/3.0: What can be done with it. Limitations, see corner cases (Max smartphones, Types of applications that can be run on it).
	- [ ] (B.A.T.M.A.N.: Test Wi-Fi mesh. Limitations, see corner cases (Max smartphones, Types of applications that can be run on it).)
- [ ] Report:
	- [ ] Structure
	- [ ] Introduction
	- [ ] Background and related works
	- [ ] Why low-cost edge computing with upcycle smartphones: Use cases, Opportunities
	- [ ] Setup description
	- [ ] Difficulties
	- [ ] Measurements
	- [ ] References: Find and read more references for the Report.
	

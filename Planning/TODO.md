# TFE planning

Start: 16/02
End: 17/03

## Issues

In `k3`: the LoadBalancerService not working: stay in status `ContainerCreating`. This seems to be because the kernel module `xt_multiport` is not present on the smartphone. To have it, we should rebuild the kernel with `xt_multiport` as a module:

	Into `Application/build´ after building:

	- Edit the kernel config: `pmbootstrap kconfig edit`
	- Set `"multiport" Multiple port match support" to `M` (press M on it) by going into:
		- `Networking support  --->`
		- `Networking options  --->`
		- `Network packet filtering framework (Netfilter)  --->`
		- `Core Netfilter Configuration  --->`
		
The problem is that when I try to rebuild the kernel package `linux-fairphone-fp2` (even without modification), I got a RuntimeError:

```bash
  LD      arch/arm/mach-msm/qdsp6v2/ultrasound/version_b/built-in.o
  LD      arch/arm/mach-msm/qdsp6v2/built-in.o
  CC      arch/arm/mach-msm/rpm_master_stat.o
  CC      arch/arm/mach-msm/rpm_rbcpr_stats_v2.o
  LD      arch/arm/mach-msm/msm_bus/built-in.o
  CC      arch/arm/mach-msm/rpm_log.o
  CC      arch/arm/mach-msm/tz_log.o
  CC      arch/arm/mach-msm/iommu_domains.o
  CC      arch/arm/mach-msm/event_timer.o
  CC      arch/arm/mach-msm/ocmem.o
  CC      arch/arm/mach-msm/ocmem_allocator.o
  CC      arch/arm/mach-msm/ocmem_notifier.o
  CC      arch/arm/mach-msm/ocmem_sched.o
  CC      arch/arm/mach-msm/ocmem_api.o
  CC      arch/arm/mach-msm/ocmem_rdm.o
  CC      arch/arm/mach-msm/ocmem_core.o
  CC      arch/arm/mach-msm/sensors_adsp.o
  CC      arch/arm/mach-msm/gpiomux-v2.o
  CC      arch/arm/mach-msm/gpiomux.o
  CC      arch/arm/mach-msm/msm_rq_stats.o
  CC      arch/arm/mach-msm/msm_show_resume_irq.o
  CC      arch/arm/mach-msm/restart.o
  CC      arch/arm/mach-msm/msm_rtb.o
  CC      arch/arm/mach-msm/msm_cache_dump.o
  CC      arch/arm/mach-msm/wdog_debug.o
  CC      arch/arm/mach-msm/msm_mem_hole.o
  CC      arch/arm/mach-msm/msm_mpmctr.o
  CC      arch/arm/mach-msm/cpufreq.o
  CC      arch/arm/mach-msm/devfreq_cpubw.o
  CC [M]  arch/arm/mach-msm/reset_modem.o
  CC [M]  arch/arm/mach-msm/dma_test.o
  CC [M]  arch/arm/mach-msm/msm-buspm-dev.o
  CC      arch/arm/mach-msm/smd_rpc_sym.o
  LD      arch/arm/mach-msm/built-in.o
>>> ERROR: linux-fairphone-fp2: build failed
(030318) [11:11:29] ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
(030318) [11:11:29] NOTE: The failed command's output is above the ^^^ line in the log file: /home/corentin/Documents/TFE/new-pmos/log.txt
(030318) [11:11:29] ERROR: Command failed (exit code 1): (native) % cd /home/pmos/build; busybox su pmos -c CARCH=armv7 SUDO_APK='abuild-apk --no-progress' CROSS_COMPILE=armv7-alpine-linux-musleabihf- CC=armv7-alpine-linux-musleabihf-gcc RUSTC_WRAPPER=/usr/bin/sccache GOCACHE=/home/pmos/.cache/go-build HOME=/home/pmos abuild -D postmarketOS -d -f
(030318) [11:11:29] See also: <https://postmarketos.org/troubleshooting>
(030318) [11:11:29] Traceback (most recent call last):
  File "/home/corentin/Documents/pmboostrap/pmbootstrap/pmb/__init__.py", line 63, in main
    getattr(frontend, args.action)(args)
  File "/home/corentin/Documents/pmboostrap/pmbootstrap/pmb/helpers/frontend.py", line 123, in build
    if not pmb.build.package(args, package, arch_package, force,
  File "/home/corentin/Documents/pmboostrap/pmbootstrap/pmb/build/_package.py", line 533, in package
    (output, cmd, env) = run_abuild(args, apkbuild, arch, strict, force, cross,
  File "/home/corentin/Documents/pmboostrap/pmbootstrap/pmb/build/_package.py", line 454, in run_abuild
    pmb.chroot.user(args, cmd, suffix, "/home/pmos/build", env=env)
  File "/home/corentin/Documents/pmboostrap/pmbootstrap/pmb/chroot/user.py", line 30, in user
    return pmb.chroot.root(args, cmd, suffix, working_dir, output,
  File "/home/corentin/Documents/pmboostrap/pmbootstrap/pmb/chroot/root.py", line 85, in root
    return pmb.helpers.run_core.core(args, msg, cmd_sudo, None, output,
  File "/home/corentin/Documents/pmboostrap/pmbootstrap/pmb/helpers/run_core.py", line 403, in core
    check_return_code(args, code, log_message)
  File "/home/corentin/Documents/pmboostrap/pmbootstrap/pmb/helpers/run_core.py", line 251, in check_return_code
    raise RuntimeError(f"Command failed (exit code {str(code)}): " +
RuntimeError: Command failed (exit code 1): (native) % cd /home/pmos/build; busybox su pmos -c CARCH=armv7 SUDO_APK='abuild-apk --no-progress' CROSS_COMPILE=armv7-alpine-linux-musleabihf- CC=armv7-alpine-linux-musleabihf-gcc RUSTC_WRAPPER=/usr/bin/sccache GOCACHE=/home/pmos/.cache/go-build HOME=/home/pmos abuild -D postmarketOS -d -f

(041744) [11:19:27] % tail -n 60 -F /home/corentin/Documents/TFE/new-pmos/log.txt
(041744) [11:19:27] *** output passed to pmbootstrap stdout, not to this log ***

```

I don't know what the error is or what I should do...
		

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
	

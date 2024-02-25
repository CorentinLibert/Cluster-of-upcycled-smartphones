# TFE Planning

## Not done

## Done

### **Friday 16/02/2024 (6 hours)** 
- Got 2 new smartphones to replace 2 old ones (because of flashing bug)
    - Flash them.
    - Set internet UCL on it.

#### Results

Flashed the 2 last smartphones (4 and 5). 
On a local Wi-Fi (proximus) tried communication (eduroam does not allows icmp). No dhcp server thus I setup static IPs on each smartphones (over 192.168.0.X) and configure routes manually.

When pinging smartphones from each others, I observed that pings between 4 and 5 (5 and 4) were fast, ~0.25ms, while ping between either 4 or 5 and 3 where very slow (~ 100ms to 450ms) or couldn't not reach destination.

I also observed that for 4 and 5, an additional new route was created when I created the static route to go outside. The "via IP" was different for each.

I suppose that this was due to the difference in distribution version between the smartphones (3 was under 6.2 and 4,5 were under 6.7). I tried to reflash smartphone 3, but I observed that after the flash, `wlan0` and `wwan` interfaces where not shown anymore. Even after reflashing, the problem persisted.

I tried several things on smartphone 2 in order to solve the problem of smartphone 3 (in order to still have a halfworking smartphone). I manage to correctly flash smartphone 2 with a new build after formating it, as said in the postmarketOS documentation: `fastboot format system`.


REMINDER: At this point, smartphone 1 and 2 where unusable. Smartphone 1 has fucked up userdata partition and smartphone 2 did not start correctly for an unknown reason.

### **Saterday 17/02/2024 (8 hours)**
- Got smartphone 1 and 3 working

#### Results
I applied the solution found previoulsy, `fastboot format system`, on smartphone 3. It worked like a charm.

I tried to resolved the problem on smartphone 1:
- `fastboot format system` had not effect
- `fastboot erase userdata`: error could not erased it.
- Tried to reinstall the Fairphone 2 android OS: not working: stuck on booting screen "Change is in your hand"
- Try to boot on other `.img` not working.

I used `TWRP` recovery mode (at boot, press power button and up volum button for ~10sec). I tried:
- Wipe all: Error with data partition: `E:primary block device '/dev/block/bootdevice/by-name/userdata' for mount point '/data' is not present`. 
- Repair Data partition: Also an error (same problem)

By analysing the folder `/dev/block/bootdevice/by-name/userdata`, where `userdata` should be, with `ls -la .`, I observed that it was filled with simlink to partition (like `mmcblk0pX`) (NOTE: you can see partition with `cat /proc/partitions`). I check on a working smartphone to which partition `userdata` should link, then created it manually with the command `ln -s /dev/block/mmcblk0p20 userdata` through the terminal of TWRP. Then I went to `Wipe` selected `data` and `change filesystem`. 

In the summary table, I saw that the field `present` that had previously the value `no`, has now the value `yes`. Still the `data` could not be repaired. Instead I move it from `ext4` to `FAT` then back to `ext4`, which worked. Then I repaired it, and it worked.

I wanted to build the distribution and then flash it but I got a new problem when building the distribution.

The root of this problem seems to be:

```bash
ERROR: unable to select packages:
  libstdc++-13.2.1_git20231014-r1:
    breaks: g++-armv7-13.2.1_git20231014-r0[libstdc++=13.2.1_git20231014-r0]
    satisfies: gcc-armv7-13.2.1_git20231014-r0[so:libstdc++.so.6]
               ccache-4.9.1-r0[so:libstdc++.so.6]
               lzip-1.24-r0[so:libstdc++.so.6]
```

Which means that `libstdc++-13.2.1_git20231014-r1` is not compatible with `g++-armv7-13.2.1_git20231014-r0`. I don't understand why this error appended, since no change where made. After 1 hour of investigation, I couldn't find the reason. Even after recloning the project from git, I still have this error. 

I think it may be a temporary problem with the repository of the package. 

After testing on the old computer, with a new setup, I got the same error.
Got the same problem on the old setup of the old PC. 

### **Sunday 18/02/2024 (5 hours)**

Try several way to reflash the last smartphone (1). In the end, I could recreate the missing simlink in order to recreate the userdata partition with TWRP. Yet, after reboot, the partition is not saved, this still not existing. 

After some other test nothing worked. Not I can't enter flash mode anymore, I don't know why... When chargind, the phone has a persistent red led. The battery seems to not be allowed to charged to more than 60% on the samrtphone (it goes to 100% if charging on another phone). 

I decided to stop losing more time on this.

### **Sunday 19/02/2024 (1 hours)**

Meeting with JBF and Nicolas. We have spoken about the smartphone problem, my futur advancement, the obtention of several smartphone in order to perform some measurement and B.A.T.M.A.N.

See meeting notes for more informations.

### **Saterday 24/02/2024 (8 hours)**

Configure a MikroTik cap ac router in order to have an access point to have Wi-Fi access and routing capabilities. The Wi-Fi performances seem rather poor:
- Ping btw 2 smartphones is rather long: ~100-200 ms
- Ping to the Wi-Fi born:
  - From Windows computer: ~1 ms
  - From Linux computer: ~3 ms
  - From Linux Smartphone: ~13ms
- Iperf3 between 2 smartphones:
  - On 2.4Ghz Wi-Fi with 40 Mhz bandwidth and 802.11n protocole: ~32 Mbits/s
  - On 5.0Ghz Wi-Fi with 80 Mhz bandwidth and 802.11ac protocole: ~72 Mbits/s
  - Using dual band with one 2.4Ghz/40Mhz/802.11n and one 5.0Ghz/80Mhz/802.11ac: ~105 Mbits/s (BUT decreasing to ~90 Mbits/s if another smartphone is connected (even if it is not sending anything...))

Trying to setup `k3s` on the smartphone/ Pacakge exist but configuration command seems to not exist. Probleme to get cluster information (cf. [this stackoverflow issue](https://stackoverflow.com/questions/76841889/kubectl-error-memcache-go265-couldn-t-get-current-server-api-group-list-get)). Try to use `minikube` to create the config, but it seems to not be available on `armv7` alpine linux (package not found) ...

Given installation command does not work, neither does curl. Problem with the current `date`stuck in _1970_... Check with `chrony` to setup correct date.

I tried to configure the k3s cluster. Could not connect an agent to a server because could not connect to proxy.
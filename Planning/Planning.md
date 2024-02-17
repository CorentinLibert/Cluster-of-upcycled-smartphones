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

By analysing the folder `/dev/block/bootdevice/by-name/userdata` where `userdata` should be, I observed that it was filled with simlink to partition like `mmb...`. I check on a working smartphone to which partition `userdata` should link, then created it manually with the command `ln -s path name` through the terminal of TWRP. Then I went to `Wipe` selected `data` and `change filesystem`. 

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

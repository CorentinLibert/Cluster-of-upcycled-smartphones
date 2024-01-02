# How to change root partition to have more memory on device

In this tutorial, we will show how to change the partition mounted on root (`/`). This will be done before flashing the device.

## Simple solution: Flash Userdata partition

Before giving the commands, here are some explanations about what is the problem and what we intend to do. If not interest, you may just skip to the section [Flash command](#flash-command)

The basic flash split the `/dev/mmcblk0p13` disk partition into 2 subpartions `/dev/mmcblk0p13p1` (for the **boot**) and `/dev/mmcblk0p13p2` (for the root). The subpartitions have respectively a size of **225.7M** and **1.7G**. This can be seen by doing `df -h` on the device after a basic flash. The output looks like this:

```bash
fp2xcvr13:~$ df -h
Filesystem                Size      Used Available Use% Mounted on
dev                      10.0M         0     10.0M   0% /dev
run                     941.5M      3.0M    938.5M   0% /run
/dev/mapper/system2       1.7G    375.5M      1.2G  23% /
/dev/mapper/system1     225.7M     38.4M    175.2M  18% /boot
shm                     941.5M         0    941.5M   0% /dev/shm
```

Where `/dev/mapper/system1` and `/dev/mapper/system2` are device-mappers composed of subpartition of the subpartion `/dev/mmcblk0p13`, respectively `/dev/mmcblk0p13p1` and `/dev/mmcblk0p13p2`, mounted on `/boot` (i.e. boot) and `/` (i.e. root).

Using `/dev/mmcblk0p13` only allow to use **1.7G** at most, even less since some are already used.

By flashing the userdata partition, we will use the subpartition `/dev/mmcblk0p20` instead of `/dev/mmcblk0p13`. This partition has **25.9G** available, which is much more than the previously **2G**. After flash, with `df -h`, we got the ouput:

```bash
fp2xcvr13:~$ df -h
Filesystem                Size      Used Available Use% Mounted on
dev                      10.0M         0     10.0M   0% /dev
run                     941.5M      3.0M    938.5M   0% /run
/dev/mapper/userdata2
                         24.7G    375.5M     23.0G   2% /
/dev/mapper/userdata1
                        225.7M     38.4M    175.2M  18% /boot
shm                     941.5M         0    941.5M   0% /dev/shm
```

Notice, that the mapper names change from `/dev/mapper/system1` and `/dev/mapper/system2` to `/dev/mapper/userdata1` and `/dev/mapper/userdata2` respectively. We now have around **23.0G ** available space.

### Flash command

For now, we followed the postmarketOS [Partition Layout documentation](https://wiki.postmarketos.org/wiki/Partition_Layout), by flashing the userdatapartition on the device, after the basic flash. 

When you device has already been flashed, simply turned it back into flash mode and execute the following command:

```bash
pmbootstrap flasher flash_rootfs --partition userdata
```


### Clear previous installation (may not be needed?)

To clear a previous postmarketOS installation from teh system partition, run: 

**NOTE:** Not working and don't seem to be needed.

```bash
fastboot format system
```

Otherwise, the initramfs may boot into the wrong installation!. 

## Complex (but better solution?) solution: Extend system partition or setup other partitions

Not done yet. Maybe in the future.


# Smartphones ID
- **9** : Screen 5
- **8** : The other 

On my PC: 
- Short cable on black smartphone, connected to the left usb port of my computer;
- Shinny cable on the blue smartphone, connected to the upper right usb port of my computer;
## Connect Smartphones together through the computer (with USB cable)

Since all the smartphones have their *IP address* **hard coded** as `172.16.42.1`, it makes it difficult to make them communicate with each other. So before all, we have to redefine the IP address of each device. 

**Remark:** In order to differentiate the devices, it's important to **modify** the current IP address and not to just add  a new one. By doing so, we remove devices from the list of devices having the hard coded IP address (172.16.42.3).

**NOTE:** The best thing to do would be to make a **"setup script"** running on the "manager device". This script would modify the IP of every device having the IP `172.16.42.1` into a incremental IP starting from `172.16.42.3`.

### Via DHCP server


### Modify the IP config on the devices

#### Connect to the device
First you have to connect to the device through `ssh`. For the first devices, you won't have any problems, however for the following devices you might not be able to connect. By default, the `ip route` redirect everything going to the subnet `172.16.0.0/16` towards the first connected device. 

One way to avoid this is to create a higher-priority route towards the device you want to connect to by doing:

```
sudo ip route add 172.16.42.1/32 dev INTERFACE src 172.16.42.2
```
Where:
- INTERFACE towards the interface of the device
- `172.16.42.2` is the IP address of the host (here the computer).

**NOTE:** If you have already create this route for a previous device, delete it before adding the new one:
```
sudo ip route del 172.16.42.1/32 dev INTERFACE src 172.16.4.2
```

After having configured the IP config on the device (see next sections), don't forget to add a route towards the device using its new IP:
```
sudo ip route add NEW_IP_SUBNET dev INTERFACE src 172.16.4.2
```
Where:
- NEW_IP_SUBNET is the new subnet of the device (e.g. 172.16.42.3/32).
- INTERFACE towards the interface of the device.
- `172.16.42.2` is the IP address of the host (here the computer).

Once every devices are configured, you should be able to ping from one device to the other through the host. If it's not the case, maybe does the host not allow **IP forwarding**. Enable it with the following command(s):

Temporarily:
```
sudo sysctl -w net.ipv4.ip_forward=1
```
Permanent:
- Open the nano editor: 
	```
	sudo nano /etc/sysctl.conf
	```
- Change the following field: `net.ipv4.ip_forward = 1`. Then `ctrl + s` to save and `ctrl + x` to leave.
- Apply changes: 
	```
	sudo sysctl -p /etc/sysctl.conf
	```
*Reference: https://linuxconfig.org/how-to-turn-on-off-ip-forwarding-in-linux*
#### Modify the IP with the `/etc/network/interfaces` config file
You can just define a `/etc/network/interfaces` file that will be used to configure the interface you define in it. Once the file is defined, it will be persistent (even after rebooting the device). Only the config file is persistent, the configuration itself seems to be reset after rebooting. 

You can create a `/etc/network/interfaces` file either with [setup-interfaces](#Using%20setup-interfaces) or with [nano editor](#Using%20nano). 

Once the config file is created, **DON'T FORGET TO RESTART YOUR NETWORKING** to make the changes effective. Run **TWO TIMES** the command 
```
sudo /etc/init.d/networking restart
```
OR
```
sudo service networking restart
```
- The first time will add the new IP address.
- The second time will remove the old IP address.
I don't know why the old IP address is not directly removed. 

**Remark 1:** Your current `ssh` connection will crashed (obviously).
**Remark 2:** As said before, the config file is persistent, so next time you should just restart two times your network.

*References:* 
- [https://wiki.postmarketos.org/wiki/USB_Network](https://wiki.postmarketos.org/wiki/USB_Network "https://wiki.postmarketos.org/wiki/USB_Network")
- [https://wiki.alpinelinux.org/wiki/Configure_Networking](https://wiki.alpinelinux.org/wiki/Configure_Networking "https://wiki.alpinelinux.org/wiki/Configure_Networking")
##### Using `setup-interfaces`
As suggested on the PostMarketOS wiki, we can manually set IP via `setup-interfaces`.

- Run the command `sudo setup-interfaces` to lauch the dynamic configuration interface.
- Select the interface `usb0`.
- Select the new IPv4 address for this interface (e.g. 172.16.42.3).
- Keep the same network mask (255.255.0.0).
- Keep the same gateway (none).
- A feedback of the config is printed, write `done` to confirm the changes.
- (Optional) After writing `done` you can see the file `/etc/network/interfaces` either by:
	- Answer `y` to *"Do you want to do any manual network configuration?"*. The file will be shown in a `vim` editor. To quit the `vim` editor, press two time on `shit + z` ( `ZZ`).
	- Answer `n` and just `cat /etc/network/interfaces` into your terminal.  
- 
##### Using `nano`
You can also just create the `/etc/network/interfaces` yourself and edit it without the `setup-interfaces` assistant.

- Run `sudo nano /etc/network/interfaces` to open the nano editor.
- Write or copy/paste the following config. Don't forget to modify the IP with the desired IP:
	```
	auto lo
	iface lo inet loopback

	auto usb0
	iface usb0 inet static
		address 172.16.42.3
		netmask 255.255.0.0
		gateway 172.16.42.2
		prefsrc 172.16.42.3
	```
	- Where the `gateway` is the IP address of the "master" (e.g. the computer)
- Save your changes with either `ctrl + s` or `ctrl + o + enter`.
- To quit nano editor, press `ctrl + x`.
#### Modify the IP with `nmcli`
Here we will use the network management client in order to modify the IP of a device through `ssh.
- Connect in `ssh` to the device via the hard coded IP address `172.16.42.1`.
- By default, `nmcli` does not manage the connection on interface `usb0`. We will allow it by running: 
	```
	sudo nmcli dev set usb0 managed yes
	```
- By running `nmcli -p device`, you should see the a new line for the device `usb0` with a default connection named *"Wired connection 1"*.
- Modify the IPv4 address and subnet of  the interface `usb0` to the one that you want (here to `172.16.42.3/16`):  
	```
	sudo nmcli con mod "Wired connection 1" ipv4.addresses 172.16.42.3/16
	```
	*"Wired connection 1"* should be the default **connection name** given by `nmcli` for the interface `usb0` when you enable the management.
- To keep this IP address static, we will have to set the IPv4 configuration to `manual` for this connection:
	```
	sudo nmcli con mod "Wired connection 1" ipv4.method manual
	```
	Without doing this, it seems like the `nmcli` change the configuration after some time, making the device unreachable.
- To save the changes, run:
	```
	sudo nmcli con up usb0
	```
- You can see this new connection with the command:
	```
	nmcli -p con show
	```

*References:*
- [https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/networking_guide/sec-configuring_ip_networking_with_nmcli](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/networking_guide/sec-configuring_ip_networking_with_nmcli "https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/networking_guide/sec-configuring_ip_networking_with_nmcli")
-  [https://developer-old.gnome.org/NetworkManager/stable/nmcli.html](https://developer-old.gnome.org/NetworkManager/stable/nmcli.html "https://developer-old.gnome.org/NetworkManager/stable/nmcli.html")

https://developer-old.gnome.org/NetworkManager/stable/nmcli.html

## Add Internet over USB

### Basic setup
The basic setup is the one describe in the [wiki of PostMarketOS](https://wiki.postmarketos.org/wiki/USB_Internet). This setup should enable internet through USB most of the time.
Below is the command needed for Ubuntu Linux Host:
#### On the smartphone:
Setup the default gateway and the DNS server address (here `1.1.1.1`, you're free to choose another one):
```
ip route add default via 172.16.42.2 dev usb0
echo nameserver 1.1.1.1 > /etc/resolv.conf
```
If the last command doesn't work you can do it manually with `nano`:
```
nano /etc/resolv.conf
```
Add `nameserver 1.1.1.1` and save `ctrl+s` then quit `ctrl+x`.

#### On the host
First enable IPv4 forwarding on the computer:
```
sysctl net.ipv4.ip_forward=1
```
Then let's configure the forwarding and the NAT on the computer (for Ubuntu Linux):
```
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -s 172.16.42.0/24 -j ACCEPT
iptables -A POSTROUTING -t nat -j MASQUERADE -s 172.16.42.0/24
iptables-save #Save changes
```

### Setup for UCLouvain firewall
As you may know, the UCLouvain firewall like to piss people off. The basic setup alone won't work when connected to UCLouvain Network (if it does, lucky you!).

The commands below should allow internet through USB despite the UCLouvain firewall. The approach is to create a SSH Tunnel.

You just need in the sshd server config, to allow TCPForwarding, and maybe other thing (GatewayPorts and/or PermitTunnel). 
```
sudo nano /etc/ssh/sshd_config
```
Then restart the ssh and sshd service:
```
sudo systemctl restart ssh
sudo systemctl restart sshd
```

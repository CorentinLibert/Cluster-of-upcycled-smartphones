# Wi-Fi Setup

`Username`: ucl email (X.X@student.uclouvain.be)

```bash
sudo nmcli con add type wifi ifname wlan0 con-name eduroam ssid eduroam
sudo nmcli con edit id eduroam
```

In `nmcli`:

```bash
set ipv4.method auto
set 802-1x.eap peap
set 802-1x.phase2-auth mschapv2
set 802-1x.identity youUsername
set 802-1x.password yourPassword
set wifi-sec.key-mgmt wpa-eap
save
activate
```

You can see if the connection is up with: `nmcli d`

#!/bin/bash

# Connect to wifi
sudo nmcli d wifi connect MT

# Restart ntpd
sudo service ntpd restart

# Sleep 3 seconds to ensure ntpd has restart and date is correct
sleep 3

# Install curl
sudo apk add curl

# Copy Flask on smartphone
mkdir FlaskApp
scp app.py pptc:~/FlaskApp
scp -r tflite pptc:~/FlaskApp
scp k3s-flask-app.tar pptc:~/FlaskApp

# Install flask (if needed)
sudo apk add py3-flask -y
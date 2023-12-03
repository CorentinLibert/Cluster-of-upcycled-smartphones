# Some informations about the measurements

## Setup

Two Fairphone 2 smartphones are connected to the computer through "Ethernet over USB". The usb connection is done between USB 3.0 port on the computer and Micro-USB B 2.0 port on the smartphones. 

USB 3.0 port on the computer is prefered over 2.0 for the alimentation of the smartphones:
- **USB 2.0:** 0.5 A and 5V.
- **USB 3.0:** 0.9 A and 5V  

## Mobile - Mobile

Iperf3 measurements between 2 smartphones using the computer as medium

## Mobile to Computer

Iperf3 measurements between a smartphone and the computer, where the computer is the server and the smartphone is the client.

## Computer to Mobile

Iperf3 measurements between a smartphone and the computer, where the smartphone is the server and the computer is the client.

## Difference between "Computer to Mobile" and "Mobile to Computer"
Since the client is the one sending the random data, I suppose that the difference is due to the fact that generating random data is more computing intensive for the CPU of the smartphone than for the CPU of the computer.

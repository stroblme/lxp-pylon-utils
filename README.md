# LXP & PylonTech Monitoring in Ruby

The code in this repository is what I use to monitor my LuxPower LXP 3600ACS inverter and a stack of PylonTech US2000 batteries (a cheaper version of a Powerwall).

## LXP 3600ACS

The inverter can be set to broadcast data about itself over UDP every 2 minutes.

`lxp_server.rb` opens a socket listening for these broadcasts and writes some JSON containing the details I want into `/tmp/lxp_data.json`.

It runs a simple webapp that returns the contents of this JSON for any request, which can be graphed in Munin or whatever.

## PylonTech US2000 (maybe US3000 too)

The batteries can be communicated with over RS232 (console) or RS485. The Pylon class can be used with either with minimal modifications; I use RS485 as it can go a lot faster (115200bps vs the console's 1200bps by default).

This uses a USB-RS485 which is on `/dev/ttyUSB0`, and fetches new information every 2 minutes, storing it in `/tmp/pylon_data.json`.

Still WIP, so far only fetching analog data is done, but getting alarms could be useful too.

# LXP & PylonTech Monitoring in Ruby

The code in this repository is what I use to monitor my LuxPower LXP 3600ACS inverter and a stack of PylonTech US2000 batteries (a cheaper version of a Powerwall).

## LXP 3600ACS

The inverter can be set to broadcast data about itself over UDP every 2 minutes.

`lxp_server.rb` opens a socket listening for these broadcasts and writes some JSON containing the details I want into `/tmp/lxp_data.json`.

It runs a simple webapp that returns the contents of this JSON for any request, which can be graphed in Munin or whatever.

Unfortunately all this is reverse engineering by watching LuxPower's own web portal for the numbers being transmitted, and matching those to UDP packets I can see on my local network at the same time - because LuxPower apparently refuse to give out the API documentation. I would like to flesh this out into being able to send the inverter commands as well, but without knowing how to calculate the checksums, there's no chance.


## PylonTech US2000 (maybe US3000 too)

The batteries can be communicated with over RS232 (console) or RS485. The Pylon class can be used with either with minimal modifications; I use RS485 as it can go a lot faster (115200bps vs the console's 1200bps by default).

Fortunately PylonTech appear a lot more hacker friendly than LuxPower, and I do have API documentation for the RS232/485 protocols for these. I'll add decoding of more packet types as I need them; for now analog and alarm data are done.

`pylon_server.rb` uses an USB-RS485 adaptor which is on `/dev/ttyUSB0`, and fetches new information regularly, storing it in `/tmp/pylon_data.json` (currently analog and alarm data are fetched). Again this is served over a HTTP webapp.

There's also a `monitor.rb` which watches for the pylon data JSON changing and renders it in a terminal. It looks a bit like this:

![monitor.rb screenshot](https://i.imgur.com/bD5EXFA.png)

It's a bit knocked together, so a bit messy, and all very hardcoded for an 80x24 terminal and 4 battery packs, but it does the job for me. Because it watches the JSON file for changes it must run on the same machine as `pylon_server` but could be trivially modified to fetch over HTTP every minute instead.


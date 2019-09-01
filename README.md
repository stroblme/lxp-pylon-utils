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

![monitor.rb screenshot](https://i.imgur.com/Fq0WrT0.png)

It's a bit knocked together, so a bit messy, and all very hardcoded for an 80x24 terminal and 4 battery packs, but it does the job for me. Because it watches the JSON file for changes it must run on the same machine as `pylon_server` but could be trivially modified to fetch over HTTP every minute instead.

On the left are individual cell voltages. These go yellow or red if the battery sends an alarm about them (voltage too low or too high). I added my own warnings to these too; if the difference between the lowest and highest cell is more than 10mV, the lowest will get a blue background and the highest will get a red background.

Below that are temperatures; the left-most is the BMS board, the next 4 are averages of various cells. Next to those is the lowest/highest cell voltage and the difference between them.

To the right is mostly abbreviations:

  * **CHG_CUR** is charge current
  * **DIS_CUR** is discharge current
  * **VOLTAGE** is entire pack voltage
  * **UV** / **OV** are module undervoltage and overvoltage respectively
  * **CHG_OC** / **DIS_OC** are (dis)charge overcurrent
  * **CHG_OT** / **DIS_OT** are (dis)charge overtemperature
  * **CHG_FET** / **DIS_FET** are green when the (dis)charge MOSFETs are on. This seems to be electrical isolation for the batteries in some alarm situations
  * **CELL_UV** is cell undervoltage. Some of the voltage displays have probably gone red to indicate which one
  * **BUZ** means the battery's alarm buzzer is sounding
  * **FULL** means the battery is full
  * **ONBAT** is green when the battery is being powered internally, from its own batteries
  * **DE** / **CE** are (dis)charge enable. These seem to signal an inverter to stop discharging or charging respectively
  * **EDC** / **ECC** are effective (dis)charge current. These seem to come on when the battery thinks it has enough current to be charging or discharging? Not sure.
  * **CI1** / **CI2** are "charge immediately". 1 comes on when the SOC is 15%-19%, and 2 comes on at 9%-13%. Probably used by inverters to decide when to charge to stop the batteries going flat.
  * **FCR** is full charge request. The Pylontech datasheet says this is to stop SOC calculations drifting too far from reality when the battery has not hada  full charge for 30 days. They suggest inverters might like to use grid charging when this comes on, to give the batteries a cycle.
  * **S4** / **S5** are more cell status bits, if they're non-zero then I think a cell has been completely disconnected from the pack. May show this in the voltages in a later update (flashing voltage?)

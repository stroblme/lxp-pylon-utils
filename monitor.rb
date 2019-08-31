#! /usr/bin/ruby
# frozen_string_literal: true

require 'bundler/setup'

require 'json'

require 'pastel'
require 'rb-inotify'
require 'tty/box'
require 'tty/cursor'

JSON_FILE = '/tmp/pylon_data.json'

# render a terminal of battery status
#
# rather than require access to RS485 this relies on pylon_server running
# and reads new data from the JSON it saves every minute

# helpers to avoid calling print all the time.
def cls
  print CURSOR.clear_screen
end

def move_to(x, y)
  print CURSOR.move_to(x, y)
end

# render a battery pack; pack is the number (1-4)
def render_pack(pack, data)
  height = 6

  pack -= 1 # start from 0
  x_offset = (pack * height) + 1 # start rendering from this line
  y_offset = 1

  analog = data['analog'][pack]
  alarm = data['alarm'][pack]

  soc = 100 * (analog['mah_remain'] / analog['mah_total'].to_f)
  stats = format('%.1fAh / %.1fAh (%d%% SOC) / %.3fV / %4.1fA / %d cycles',
                 analog['mah_remain'] / 1000.0,
                 analog['mah_total'] / 1000.0,
                 soc,
                 analog['pack_voltage'],
                 analog['current'],
                 analog['pack_cycles'])

  print TTY::Box.frame(top: x_offset - 1, left: 0,
                       width: 80, height: height,
                       title: { top_left: "Pack #{pack + 1}",
                                top_right: stats })

  # render voltages as 3 lines with 5 voltages in each
  analog['voltages'].each_slice(5).each_with_index do |arr, idx|
    arr.each_with_index do |voltage, idx2|
      arr_offset = (idx * 5) + idx2
      move_to(y_offset + idx2 * 8, x_offset + idx)
      str = format('%.03fv', voltage)
      print case alarm['voltages'][arr_offset]
            when 0 then PASTEL.green(str)
            when 1 then PASTEL.red(str)
            when 2 then PASTEL.yellow(str)
            end
    end
  end

  analog['temps'].each_with_index do |temp, idx|
    move_to(y_offset + idx * 8, x_offset + 3)
    str = format('%5.01fC', temp)
    print case alarm['temps'][idx]
          when 0 then PASTEL.green(str)
          when 1 then PASTEL.red(str)
          when 2 then PASTEL.yellow(str)
          end
  end

  # add a stat of my own, mV difference between low/high cell
  move_to(y_offset + 40, x_offset + 3)
  max_v = analog['voltages'].max
  min_v = analog['voltages'].min
  printf('d: %2dmV', (max_v - min_v) * 1000.0)

  # rest are just alarm booleans
  move_to(y_offset + 40, x_offset)
  str = 'CHARGE'
  print case alarm['charge_current']
        when 0 then PASTEL.green(str)
        when 1 then PASTEL.red(str)
        when 2 then PASTEL.yellow(str)
        end

  move_to(y_offset + 40, x_offset + 1)
  str = 'DISCHRG'
  print case alarm['discharge_current']
        when 0 then PASTEL.green(str)
        when 1 then PASTEL.red(str)
        when 2 then PASTEL.yellow(str)
        end

  move_to(y_offset + 40, x_offset + 2)
  str = 'VOLTAGE'
  print case alarm['pack_voltage']
        when 0 then PASTEL.green(str)
        when 1 then PASTEL.red(str)
        when 2 then PASTEL.yellow(str)
        end

  move_to(y_offset + 49, x_offset)
  # module over voltage
  print red_if('OV', alarm['status1int'] & 0x1 == 0x1)

  move_to(y_offset + 52, x_offset)
  # cell under voltage
  print red_if('CUV', alarm['status1int'] & 0x2 == 0x2)

  move_to(y_offset + 56, x_offset)
  # charge over current
  print red_if('COC', alarm['status1int'] & 0x4 == 0x4)

  move_to(y_offset + 60, x_offset)
  # discharge over current
  print red_if('DOC', alarm['status1int'] & 0x10 == 0x10)

  move_to(y_offset + 64, x_offset)
  # discharge over temp
  print red_if('DOT', alarm['status1int'] & 0x20 == 0x20)

  move_to(y_offset + 68, x_offset)
  # charge over temp
  print red_if('COT', alarm['status1int'] & 0x40 == 0x40)

  move_to(y_offset + 72, x_offset)
  # module under voltage
  print red_if('UV', alarm['status1int'] & 0x80 == 0x80)

  # status2
  move_to(y_offset + 49, x_offset + 1)
  # charge mosfet
  print green_if('C_MOSFET', alarm['status2int'] & 0x2 == 0x2)

  move_to(y_offset + 59, x_offset + 1)
  # discharge mosfet
  print green_if('D_MOSFET', alarm['status2int'] & 0x4 == 0x4)

  move_to(y_offset + 72, x_offset + 1)
  # using battery module power
  print green_if('ONBATT', alarm['status2int'] & 0x8 == 0x8)

  move_to(y_offset + 49, x_offset + 2)
  print red_if('BUZZ', alarm['status3int'] & 0x1 == 0x1)

  move_to(y_offset + 58, x_offset + 2)
  # fully charged
  print green_if('FULL', alarm['status3int'] & 0x8 == 0x8)

  move_to(y_offset + 70, x_offset + 2)
  # effective discharge current
  print green_if('EDC', alarm['status3int'] & 0x40 == 0x40)

  move_to(y_offset + 75, x_offset + 2)
  # effective charge current
  print green_if('ECC', alarm['status3int'] & 0x80 == 0x80)

  # status 4 and 5
  move_to(y_offset + 49, x_offset + 3)
  print red_if("S4: #{alarm['status4']}", alarm['status4int'].positive?)
  move_to(y_offset + 65, x_offset + 3)
  print red_if("S5: #{alarm['status5']}", alarm['status5int'].positive?)
end

def green_if(str, bool)
  bool ? PASTEL.green(str) : str
end

def red_if(str, bool)
  bool ? PASTEL.red(str) : str
end

def render_data(data)
  render_pack(1, data)
  render_pack(2, data)
  render_pack(3, data)
  render_pack(4, data)
end

fh = File.open(JSON_FILE, 'r')

PASTEL = Pastel.new
CURSOR = TTY::Cursor
cls

data = JSON.parse(fh.read)
render_data(data) # initial render

notifier = INotify::Notifier.new
notifier.watch(JSON_FILE, :modify) do
  fh.rewind
  begin
    data = JSON.parse(fh.read)
    render_data(data)
  rescue StandardError
    # ignore JSON parse error for now (need atomic file write?)
  end
end

notifier.run

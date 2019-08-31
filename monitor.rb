#! /usr/bin/ruby
# frozen_string_literal: true

require 'bundler/setup'

require 'json'

require 'pastel'
require 'rb-inotify'
require 'tty/box'
require 'tty/cursor'

JSON_FILE = '/tmp/pylon_data.json'

# render a battery pack; pack is the number (1-4)
def render_pack(pack, data)
  # string to build and return
  r = String.new

  height = 6

  pack -= 1 # start from 0
  x_offset = (pack * height) + 1 # start rendering from this line
  y_offset = 1

  analog = data['analog'][pack]
  alarm = data['alarm'][pack]

  soc = 100 * (analog['mah_remain'] / analog['mah_total'].to_f)
  stats = format('%.1fAh / %.1fAh (%d%% SOC) / ' \
                 '%.3fV @ %4.1fA = %3dW / %d cycles',
                 analog['mah_remain'] / 1000.0,
                 analog['mah_total'] / 1000.0,
                 soc,
                 analog['pack_voltage'],
                 analog['current'],
                 analog['pack_voltage'] * analog['current'],
                 analog['pack_cycles'])

  r << TTY::Box.frame(top: x_offset - 1, left: 0,
                      width: 80, height: height,
                      style: { border: { fg: :bright_yellow } },
                      title: { top_left: "Pack #{pack + 1}",
                               top_right: stats })

  # render voltages as 3 lines with 5 voltages in each
  analog['voltages'].each_slice(5).each_with_index do |arr, idx|
    arr.each_with_index do |voltage, idx2|
      arr_offset = (idx * 5) + idx2
      r << CURSOR.move_to(y_offset + idx2 * 8, x_offset + idx)
      str = format('%.03fv', voltage)
      r << case alarm['voltages'][arr_offset]
           when 0 then PASTEL.green(str)
           when 1 then PASTEL.red(str)
           when 2 then PASTEL.yellow(str)
           end
    end
  end

  analog['temps'].each_with_index do |temp, idx|
    r << CURSOR.move_to(y_offset + idx * 8, x_offset + 3)
    str = format('%5.01fC', temp)
    r << case alarm['temps'][idx]
         when 0 then PASTEL.green(str)
         when 1 then PASTEL.red(str)
         when 2 then PASTEL.yellow(str)
         end
  end

  # add a stat of my own, mV difference between low/high cell
  r << CURSOR.move_to(y_offset + 40, x_offset + 3)
  max_v = analog['voltages'].max
  min_v = analog['voltages'].min
  r << format('d: %2dmV', (max_v - min_v) * 1000.0)

  # rest are just alarm booleans
  r << CURSOR.move_to(y_offset + 40, x_offset)
  str = 'CHARGE'
  r << case alarm['charge_current']
       when 0 then PASTEL.green(str)
       when 1 then PASTEL.red(str)
       when 2 then PASTEL.yellow(str)
       end

  r << CURSOR.move_to(y_offset + 40, x_offset + 1)
  str = 'DISCHRG'
  r << case alarm['discharge_current']
       when 0 then PASTEL.green(str)
       when 1 then PASTEL.red(str)
       when 2 then PASTEL.yellow(str)
       end

  r << CURSOR.move_to(y_offset + 40, x_offset + 2)
  str = 'VOLTAGE'
  r << case alarm['pack_voltage']
       when 0 then PASTEL.green(str)
       when 1 then PASTEL.red(str)
       when 2 then PASTEL.yellow(str)
       end

  r << CURSOR.move_to(y_offset + 49, x_offset)
  # module over voltage
  r << red_if('OV', alarm['status1int'] & 0x1 == 0x1)

  r << CURSOR.move_to(y_offset + 52, x_offset)
  # cell under voltage
  r << red_if('CUV', alarm['status1int'] & 0x2 == 0x2)

  r << CURSOR.move_to(y_offset + 56, x_offset)
  # charge over current
  r << red_if('COC', alarm['status1int'] & 0x4 == 0x4)

  r << CURSOR.move_to(y_offset + 60, x_offset)
  # discharge over current
  r << red_if('DOC', alarm['status1int'] & 0x10 == 0x10)

  r << CURSOR.move_to(y_offset + 64, x_offset)
  # discharge over temp
  r << red_if('DOT', alarm['status1int'] & 0x20 == 0x20)

  r << CURSOR.move_to(y_offset + 68, x_offset)
  # charge over temp
  r << red_if('COT', alarm['status1int'] & 0x40 == 0x40)

  r << CURSOR.move_to(y_offset + 72, x_offset)
  # module under voltage
  r << red_if('UV', alarm['status1int'] & 0x80 == 0x80)

  # status2
  r << CURSOR.move_to(y_offset + 49, x_offset + 1)
  # charge mosfet
  r << green_if('C_MOSFET', alarm['status2int'] & 0x2 == 0x2)

  r << CURSOR.move_to(y_offset + 59, x_offset + 1)
  # discharge mosfet
  r << green_if('D_MOSFET', alarm['status2int'] & 0x4 == 0x4)

  r << CURSOR.move_to(y_offset + 72, x_offset + 1)
  # using battery module power
  r << green_if('ONBATT', alarm['status2int'] & 0x8 == 0x8)

  r << CURSOR.move_to(y_offset + 49, x_offset + 2)
  r << red_if('BUZZ', alarm['status3int'] & 0x1 == 0x1)

  r << CURSOR.move_to(y_offset + 58, x_offset + 2)
  # fully charged
  r << green_if('FULL', alarm['status3int'] & 0x8 == 0x8)

  r << CURSOR.move_to(y_offset + 70, x_offset + 2)
  # effective discharge current
  r << green_if('EDC', alarm['status3int'] & 0x40 == 0x40)

  r << CURSOR.move_to(y_offset + 75, x_offset + 2)
  # effective charge current
  r << green_if('ECC', alarm['status3int'] & 0x80 == 0x80)

  # status 4 and 5
  r << CURSOR.move_to(y_offset + 49, x_offset + 3)
  r << red_if("S4: #{alarm['status4']}", alarm['status4int'].positive?)
  r << CURSOR.move_to(y_offset + 65, x_offset + 3)
  r << red_if("S5: #{alarm['status5']}", alarm['status5int'].positive?)

  r
end

def green_if(str, bool)
  bool ? PASTEL.green(str) : str
end

def red_if(str, bool)
  bool ? PASTEL.red(str) : str
end

def render_data(data)
  print render_pack(1, data)
  print render_pack(2, data)
  print render_pack(3, data)
  print render_pack(4, data)
end

fh = File.open(JSON_FILE, 'r')

PASTEL = Pastel.new
CURSOR = TTY::Cursor
print CURSOR.clear_screen

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

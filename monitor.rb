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
  ci = data['charge_info'][pack]

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

  # min/max cell display, and mV difference between them
  max_v = analog['voltages'].max
  min_v = analog['voltages'].min
  r << CURSOR.move_to(y_offset + 21, x_offset + 3)
  r << format('(%.3fv - %.3fv dV: %2dmV)',
              min_v, max_v, (max_v * 1000) - (min_v * 1000))

  # render voltages as 3 lines with 5 voltages in each
  analog['voltages'].each_slice(5).each_with_index do |arr, idx|
    arr.each_with_index do |voltage, idx2|
      arr_offset = (idx * 5) + idx2
      r << CURSOR.move_to(y_offset + idx2 * 8, x_offset + idx)
      str = format('%.03fv', voltage)
      if max_v - min_v > 0.010 # 10mV
        str = PASTEL.bold.on_blue(str) if voltage == min_v
        str = PASTEL.bold.on_red(str) if voltage == max_v
      end
      r << case alarm['voltages'][arr_offset]
           when 0 then PASTEL.green(str)
           when 1 then PASTEL.clear.red(str)
           when 2 then PASTEL.clear.yellow(str)
           end
    end
  end

  analog['temps'].each_with_index do |temp, idx|
    r << CURSOR.move_to(y_offset + (idx * 4), x_offset + 3)
    str = format('%dC', temp)
    r << case alarm['temps'][idx]
         when 0 then PASTEL.green(str)
         when 1 then PASTEL.red(str)
         when 2 then PASTEL.yellow(str)
         end
  end

  # rest are just alarm booleans
  r << CURSOR.move_to(y_offset + 40, x_offset)
  str = 'CHG_CUR'
  r << case alarm['charge_current']
       when 0 then PASTEL.green(str)
       when 1 then PASTEL.red(str)
       when 2 then PASTEL.yellow(str)
       end

  r << CURSOR.move_to(y_offset + 40, x_offset + 1)
  str = 'DIS_CUR'
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
  # module under voltage
  r << red_if('UV', alarm['status1int'] & 0x80 == 0x80)

  r << CURSOR.move_to(y_offset + 53, x_offset)
  # module over voltage
  r << red_if('OV', alarm['status1int'] & 0x1 == 0x1)

  r << CURSOR.move_to(y_offset + 57, x_offset)
  # charge over current
  r << red_if('CHG_OC', alarm['status1int'] & 0x4 == 0x4)

  r << CURSOR.move_to(y_offset + 57, x_offset + 1)
  # discharge over current
  r << red_if('DIS_OC', alarm['status1int'] & 0x10 == 0x10)

  r << CURSOR.move_to(y_offset + 64, x_offset)
  # charge over temp
  r << red_if('CHG_OT', alarm['status1int'] & 0x40 == 0x40)

  r << CURSOR.move_to(y_offset + 64, x_offset + 1)
  # discharge over temp
  r << red_if('DIS_OT', alarm['status1int'] & 0x20 == 0x20)

  r << CURSOR.move_to(y_offset + 71, x_offset)
  # charge mosfet
  r << green_if('CHG_FET', alarm['status2int'] & 0x2 == 0x2)

  r << CURSOR.move_to(y_offset + 49, x_offset + 1)
  # cell under voltage
  r << red_if('CELL_UV', alarm['status1int'] & 0x2 == 0x2)

  r << CURSOR.move_to(y_offset + 71, x_offset + 1)
  # discharge mosfet
  r << green_if('DIS_FET', alarm['status2int'] & 0x4 == 0x4)

  r << CURSOR.move_to(y_offset + 49, x_offset + 2)
  r << red_if('BUZ', alarm['status3int'] & 0x1 == 0x1)

  r << CURSOR.move_to(y_offset + 53, x_offset + 2)
  # fully charged
  r << green_if('FULL', alarm['status3int'] & 0x8 == 0x8)

  r << CURSOR.move_to(y_offset + 58, x_offset + 2)
  # using battery module power
  r << green_if('ONBAT', alarm['status2int'] & 0x8 == 0x8)

  r << CURSOR.move_to(y_offset + 64, x_offset + 2)
  # discharge enable
  r << green_if('DE', ci['charge_statusint'] & 0x40 == 0x40)

  r << CURSOR.move_to(y_offset + 67, x_offset + 2)
  # charge enable
  r << green_if('CE', ci['charge_statusint'] & 0x80 == 0x80)

  r << CURSOR.move_to(y_offset + 70, x_offset + 2)
  # effective discharge current
  r << green_if('EDC', alarm['status3int'] & 0x40 == 0x40)

  r << CURSOR.move_to(y_offset + 75, x_offset + 2)
  # effective charge current
  r << green_if('ECC', alarm['status3int'] & 0x80 == 0x80)

  r << CURSOR.move_to(y_offset + 49, x_offset + 3)
  # charge immediately (1); 5-9%
  r << red_if('CI1', ci['charge_statusint'] & 0x20 == 0x20)

  r << CURSOR.move_to(y_offset + 53, x_offset + 3)
  # charge immediately (2); 9-13%
  r << red_if('CI2', ci['charge_statusint'] & 0x10 == 0x10)

  r << CURSOR.move_to(y_offset + 58, x_offset + 3)
  # full charge request
  r << red_if('FCR', ci['charge_statusint'] & 0x8 == 0x8)

  r << CURSOR.move_to(y_offset + 63, x_offset + 3)
  r << red_if(format('S4: %03d', alarm['status4int']),
              alarm['status4int'].positive?)

  r << CURSOR.move_to(y_offset + 71, x_offset + 3)
  r << red_if(format('S5: %03d', alarm['status5int']),
              alarm['status5int'].positive?)

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

CURSOR.invisible do
  data = JSON.parse(fh.read)
  render_data(data) # initial render

  notifier = INotify::Notifier.new
  notifier.watch(JSON_FILE, :modify) do
    begin
      fh.rewind
      data = JSON.parse(fh.read)
      render_data(data)
    rescue JSON::ParserError
      # ignore JSON parse error for now (need atomic file write?)
      retry
    end
  end

  notifier.run
end

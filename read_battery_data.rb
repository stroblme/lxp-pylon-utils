require 'rubyserial'
require 'pp'
require 'json'
require 'roda'

JSON_FILE = '/tmp/us2000_battery_data.json'
class Web < Roda
  route do |r|
    r.get do
      File.read(JSON_FILE)
    end
  end
end

# start a dead simple webserver
Thread.new do
  Rack::Server.start(Host: '0.0.0.0', app: Web)
end

def read_until_done(port)
  r = String.new

  loop do
    sleep 1
    input = port.read(4096)
    r << input
    break if input.empty?
  end

  r
end


def parse_bat(input)
  r = []

  input.lines.each do |line|
    next if line['bat'] # command echo?
    next if line['@'] # start
    next if line['Battery'] # header
    break if line['$$'] # end
    break if line['Command completed'] # end

    parts = line.split

    r << {
      idx: parts[0].to_i,
      voltage: parts[1].to_i / 1000.0,
      current: parts[2].to_i / 1000.0,
      temp: parts[3].to_i / 1000.0
      # state
      # vstate
      # cstate
      # tstate
      # coulomb %
      # mah
    }
  end

  r
end


puts "Send activation.."
port = Serial.new('/dev/ttyUSB0', 1200)
bytes = %w(7E 32 30 30 31 34 36 38 32 43 30 30 34 38 35 32 30 46 43 43 33 0D)
str = bytes.pack('H*' * bytes.length)
port.write(str)

sleep 1

port = Serial.new('/dev/ttyUSB0', 115200)
bytes = %w(0D 0A)
str = bytes.pack('H*' * bytes.length)
port.write(str)
until port.read(80) == "\n\rpylon>\n\rpylon>"
  puts "wait for prompt.."
  port.write(str)
  sleep 1
end

puts "entering main loop"

loop do
  r = {}
  4.times do |n|
    port.write("bat #{n+1}\r\n") # 1-4
    r[n+1] = parse_bat(read_until_done(port))
  end

  json = JSON.generate(r)
  File.write(JSON_FILE, json)

  sleep 60
end

port.write("cmdquit\r\n")

# frozen_string_literal: true

# Decode packets from a LuxPower LXP ACS inverter.
#
# Sample usage:
#
#   # set your inverter to do UDP broadcasts to port 4346
#
#   ss = UDPSocket.new
#   ss.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
#   ss.bind('255.255.255.255', 4346)
#
#   loop do
#     data = ss.recvfrom(2000)[0]
#     lxp.decode(data)
#
#     if lxp.populated
#       # all 3 packets have been received,
#       # use lxp accessors for whatever you want
#     end
#   end

class LXP
  attr_reader :populated

  # Packet 1
  attr_reader :status
  attr_reader :v_bat, :soc
  attr_reader :p_pv, :p_charge, :p_discharge
  attr_reader :v_acr, :f_ac # Grid side AC
  attr_reader :p_inv, :p_rec
  attr_reader :v_eps, :f_eps # EPS side AC
  attr_reader :e_pv_day, :e_inv_day, :e_rec_day, :e_chg_day,
              :e_dischg_day, :e_eps_day, :e_togrid_day, :e_touser_day
  attr_reader :v_bus1, :v_bus2

  # Packet 2
  attr_reader :e_pv_all, :e_inv_all, :e_rec_all, :e_chg_all,
              :e_dischg_all, :e_eps_all, :e_togrid_all, :e_touser_all
  attr_reader :t_inner, :t_rad1, :t_rad2

  # Packet 3
  attr_reader :max_chg_curr, :max_dischg_curr
  attr_reader :charge_volt_ref, :dischg_cut_volt
  attr_reader :bat_status0, :bat_status1, :bat_status2, :bat_status3,
              :bat_status4, :bat_status5, :bat_status6, :bat_status7,
              :bat_status8, :bat_status9, :bat_status_inv

  # Given a packet of data from an LXP inverter, decode it and populate
  # instance variables.
  def decode(packet)
    bytes = packet.bytes # array of ints

    # reset our populated state. we'll set it again after packet 3.
    @populated = false

    # puts "#{bytes[4]} #{bytes[32]} #{bytes.length}\n"

    # bytes[4] is 13 for the leading (identifier?) packet, and 111 for
    # all subsequent data packets. ignore this one.
    return if bytes[4] == 13

    # all the data packets seem to be 117 bytes in length.
    # abort if this one isn't..
    return if bytes.length != 117

    case bytes[32]
    when 0 then decode_bytes1(bytes)
    when 40 then decode_bytes2(bytes)
    when 80 then decode_bytes3(bytes)
    end
  end

  private

  def decode_bytes1(bytes)
    @status = bytes[35]

    # LSB first
    @v_bat = int(bytes[43..44], :lsb) / 10.0 # V
    @soc = bytes[45] # %
    @p_pv = int(bytes[49..50], :lsb) # W
    @p_charge = int(bytes[55..56], :lsb) # W
    @p_discharge = int(bytes[57..58], :lsb) # W
    @v_acr = int(bytes[59..60], :lsb) / 10.0 # V
    @f_ac = int(bytes[65..66], :lsb) / 100.0 # Hz

    @p_inv = int(bytes[67..68], :lsb) / 10.0 # W
    @p_rec = int(bytes[69..70], :lsb) / 10.0 # W
    @v_eps = int(bytes[75..76], :lsb) / 10.0 # V
    @f_eps = int(bytes[81..82], :lsb) / 100.0 # Hz

    # now seems to shift to MSB first

    # p bytes[83..85] # peps / seps?

    @p_togrid = int(bytes[86..87], :msb) # W
    @p_touser = int(bytes[88..89], :msb) # W

    @e_pv_day = int(bytes[90..91], :msb) / 10.0 # kWh
    # p bytes[92..95] # unknown..
    @e_inv_day = int(bytes[96..97], :msb) / 10.0 # kWh
    @e_rec_day = int(bytes[98..99], :msb) / 10.0 # kWh
    @e_chg_day = int(bytes[100..101], :msb) / 10.0 # kWh
    @e_dischg_day = int(bytes[102..103], :msb) / 10.0 # kWh
    @e_eps_day = int(bytes[104..105], :msb) / 10.0 # kWh
    @e_togrid_day = int(bytes[106..107], :msb) / 10.0 # kWh
    @e_touser_day = int(bytes[108..109], :msb) / 10.0 # kWh

    # LSB again.. wtf :)
    @v_bus1 = int(bytes[111..112], :lsb) / 10.0 # V
    @v_bus2 = int(bytes[113..114], :lsb) / 10.0 # V
  end

  def decode_bytes2(bytes)
    @e_pv_all = int(bytes[35..38], :lsb) / 10.0 # kWh
    @e_inv_all = int(bytes[47..50], :lsb) / 10.0 # kWh
    @e_rec_all = int(bytes[51..54], :lsb) / 10.0 # kWh
    @e_chg_all = int(bytes[55..58], :lsb) / 10.0 # kWh
    @e_dischg_all = int(bytes[59..62], :lsb) / 10.0 # kWh
    @e_eps_all = int(bytes[63..66], :lsb) / 10.0 # kWh
    @e_togrid_all = int(bytes[67..70], :lsb) / 10.0 # kWh
    @e_touser_all = int(bytes[71..74], :lsb) / 10.0 # kWh

    # p bytes[75..81] # fault/warning codes?

    @t_inner = int(bytes[82..83], :msb)
    @t_rad1 = int(bytes[84..85], :msb)
    @t_rad2 = int(bytes[86..87], :msb)
  end

  def decode_bytes3(bytes)
    @max_chg_curr = int(bytes[37..38], :lsb) / 100.0 # A?
    @max_dischg_curr = int(bytes[39..40], :lsb) / 100.0 # A?
    @charge_volt_ref = int(bytes[41..42], :lsb) / 10.0 # V
    @dischg_cut_volt = int(bytes[43..44], :lsb) / 10.0 # V

    @bat_status0 = bytes[45]
    @bat_status1 = bytes[47]
    @bat_status2 = bytes[49]
    @bat_status3 = bytes[51]
    @bat_status4 = bytes[53]
    @bat_status5 = bytes[55]
    @bat_status6 = bytes[57]
    @bat_status7 = bytes[59]
    @bat_status8 = bytes[61]
    @bat_status9 = bytes[63]
    @bat_status_inv = bytes[65]

    @populated = true
  end

  # Decode an int from the given bytes
  def int(bytes, order)
    bytes = bytes.reverse if order == :msb
    bytes.each_with_index.map { |b, idx| b << (idx * 8) }.inject(:|)
  end
end

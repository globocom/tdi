#
# Copyright (C) 2013-2015 Globo.com
#

# This file is part of TDI.

# TDI is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# TDI is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with TDI.  If not, see <http://www.gnu.org/licenses/>.

require 'awesome_print'
require 'socket'
require 'ipaddress'
require 'dnsruby'

# Awesome Print config.
def a_p(obj)
  ap obj, {
    indent: 2,
    index: false,
    color: {
      args:       :pale,
      array:      :white,
      bigdecimal: :blue,
      class:      :yellow,
      date:       :greenish,
      falseclass: :red,
      fixnum:     :blue,
      float:      :blue,
      hash:       :blue,
      keyword:    :cyan,
      method:     :purpleish,
      nilclass:   :red,
      rational:   :blue,
      string:     :green,
      struct:     :pale,
      symbol:     :cyanish,
      time:       :greenish,
      trueclass:  :green,
      variable:   :cyanish,
    }
  }
end

# Return a list of local networks and it's details.
def local_networks
  Socket.getifaddrs.each.select { |ifaddr| ifaddr.addr.ipv4? and ! ifaddr.name.start_with?('lo') }.
    map do |ifaddr|
      ip = IPAddress::IPv4.new("#{ifaddr.addr.ip_address}/#{ifaddr.netmask.ip_address}")
      {
        interface: ifaddr.name,
        network: ip.network.address,
        netmask: ip.netmask,
        prefix: ip.prefix,
        broadcast: ip.broadcast.address,
        ipv4: ip.address,
      }
    end
end

# Return the origin network to be used when trying to connect to a remote
# service.
#
# Stolen from:
#
# https://coderrr.wordpress.com/2008/05/28/get-your-local-ip-address/
#
# The above code does NOT make a connection or send any packets. Since UDP is a
# stateless protocol connect() merely makes a system call which figures out how
# to route the packets based on the address and what interface (and therefore IP
# address) it should bind to. addr() returns an array containing the family
# (AF_INET), local port, and local address (which is what we want) of the socket.
# This is a good alternative to `ifconfig`/`ipconfig` solutions because it
# doesn’t spawn a shell and it works the same on all systems.
def origin_network(remote)
  orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true

  host = remote # host (name or IP)
  addr = getaddress(remote, raise_exception: false)

  UDPSocket.open do |s|
    begin
      s.connect(remote, 1)
      res = {from: local_networks.each.select { |locnet| locnet[:ipv4].eql?(s.addr.last) }.first}
    rescue
      res = {from: nil}
    end

    res[:to] = {host: host, addr: addr}

    return res
  end

ensure
  Socket.do_not_reverse_lookup = orig
end

# Return IP address.
def getaddress(host, raise_exception: true)
  if IPAddress.valid?(host)
    return host # use address (already IP)
  else
    dns = Dnsruby::DNS.new # get address (resolve name to IP)
    dns.config.apply_domain = false
    if raise_exception
      return dns.getaddress(host).to_s
    else
      return dns.getaddress(host).to_s rescue nil
    end
  end
end

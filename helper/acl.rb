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

require_relative '../lib/util'
require 'socket'
require 'timeout'

class TDIPlan < TDI
  def acl(role_name, plan_name, plan_content)
    plan_content.select { |key, val|
      val.is_a?(Hash)
    }.each_pair do |case_name, case_content|
      # Parse.
      host          = case_name
      ports         = [case_content['port']].flatten
      timeout_limit = case_content['timeout'].nil? ? 1 : case_content['timeout'].to_i

      # User.
      user = Etc.getpwuid(Process.euid).name

      # ACL.
      ports.each do |port|
        # Initialize vars.
        addr = nil
        res_str = "#{host}:#{port}"
        res_dict = {host: host, addr: addr, port: port, net: origin_network(host)}

        begin
          addr = getaddress(host).to_s
          res_str = "#{host}/#{addr}:#{port}"
          res_dict = {host: host, addr: addr, port: port, net: origin_network(host)}

          timeout(timeout_limit) do
            begin
              sock = TCPSocket.open(addr, port)
              sock.close
              res_msg = "ACL (#{user}): #{res_str}"
              success role_name, plan_name, res_msg, res_dict
            rescue Errno::ECONNREFUSED, Errno::ECONNRESET => e
              res_msg = "ACL (#{user}): #{res_str} (#{e.message})"
              warning role_name, plan_name, res_msg, res_dict
            rescue => e
              res_msg = "ACL (#{user}): #{res_str} (#{e.message})"
              failure role_name, plan_name, res_msg, res_dict
            end
          end
        rescue Timeout::Error => e
          res_msg = "ACL (#{user}): #{res_str} (Timed out (#{timeout_limit}s) #{e.message})"
          failure role_name, plan_name, res_msg, res_dict
        rescue => e
          res_msg = "ACL (#{user}): #{res_str} (#{e.message})"
          failure role_name, plan_name, res_msg, res_dict
        end
      end
    end
  end
end

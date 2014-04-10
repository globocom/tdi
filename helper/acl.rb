#
# Copyright (C) 2013-2014 Globo.com
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

require 'socket'
require 'timeout'
require 'etc'

class TDIPlan < TDI
  def acl(plan)
    plan.select { |key, val|
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
        begin
          timeout(timeout_limit) do
            begin
              sock = TCPSocket.open(host, port)
              sock.close
              success "ACL (#{user}): #{host}:#{port}"
            rescue Errno::ECONNREFUSED
              warning "ACL (#{user}): #{host}:#{port}"
            rescue Errno::ECONNRESET, Errno::ETIMEDOUT
              failure "ACL (#{user}): Connection Refused #{host}:#{port}"
            end
          end
        rescue Timeout::Error
          failure "ACL (#{user}): Timed out (#{timeout_limit}s) #{host}:#{port}"
        end
      end
    end
  end
end

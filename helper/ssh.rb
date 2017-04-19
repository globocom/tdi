#
# Copyright (C) 2013-2017 Globo.com
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
require 'net/ssh'
require 'timeout'

class TDIPlan < TDI
  def ssh(role_name, plan_name, plan_content)
    plan_content.select { |key, val|
      val.is_a?(Hash)
    }.each_pair do |case_name, case_content|
      # Validate.
      unless /^[^@]+@[^@]+$/.match(case_name)
        puts "ERR: Invalid ssh plan format \"#{case_name}\". Case name must match pattern \"user@host\".".light_magenta
        exit 1
      end

      # Parse.
      remote_user = case_name.split('@').first
      host = case_name.split('@').last
      local_users = [case_content['local_user']].flatten
      timeout_limit = case_content['timeout'].nil? ? 5 : case_content['timeout'].to_i

      # Users.
      local_users.each do |local_user|
        # Privileged user.
        begin
          Process.euid = 0
        rescue => e
          puts "ERR: Must run as root to change user credentials (#{e.message}).".light_magenta
          exit 1
        end

        # Change credentials to local user.
        begin
          Process.euid = Etc.getpwnam(local_user).uid
          # SSH needs to know the user homedir in order to use the right
          # private/public key pair to authenticate.
          ENV['HOME'] = Etc.getpwnam(local_user).dir
        rescue => e
          puts "ERR: User \"#{local_user}\" not found (#{e.message}).".light_magenta
          exit 1
        end

        # Initialize vars.
        addr = nil
        res_str = "#{remote_user}@#{host}"
        res_dict = {local_user: local_user, remote_user: remote_user, host: host, addr: addr, net: origin_network(host)}

        begin
          addr = getaddress(host).to_s
          res_str = "#{remote_user}@#{host}/#{addr}"
          res_dict = {local_user: local_user, remote_user: remote_user, host: host, addr: addr, net: origin_network(host)}

          Timeout::timeout(timeout_limit) do
            ssh_session = Net::SSH.start(host,
                                         remote_user,
                                         auth_methods: ['publickey'])
            ssh_session.close
            res_msg = "SSH (#{local_user}): #{res_str}"
            success role_name, plan_name, res_msg, res_dict
          end
        rescue Timeout::Error => e
          res_msg = "SSH (#{local_user}): #{res_str} (Timed out (#{timeout_limit}s) #{e.message})"
          failure role_name, plan_name, res_msg, res_dict
        rescue => e
          res_msg = "SSH (#{local_user}): #{res_str} (#{e.message})"
          failure role_name, plan_name, res_msg, res_dict
        end
      end
    end

    # Change credentials back to privileged user.
    Process.euid = 0
  end
end

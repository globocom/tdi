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

require 'net/ssh'
require 'etc'

class TDIPlan < TDI
  def ssh(plan)
    plan.select { |key, val|
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

      # Users.
      local_users.each do |local_user|
        # Privileged user.
        begin
          Process.euid = 0
        rescue => e
          puts "ERR: Must run as root to change user credentials #{e}).".light_magenta
          exit 1
        end

        # Change credentials to local user.
        begin
          Process.euid = Etc.getpwnam(local_user).uid
          # SSH needs to know the user homedir in order to use the right
          # private/public key pair to authenticate.
          ENV['HOME'] = Etc.getpwnam(local_user).dir
        rescue => e
          puts "ERR: User \"#{local_user}\" not found (#{e}).".light_magenta
          exit 1
        end

        begin
          timeout(5) do
            ssh_session = Net::SSH.start(host,
                                         remote_user,
                                         :auth_methods => ['publickey'])
            ssh_session.close
            success "SSH (#{local_user}): #{remote_user}@#{host}"
          end
        rescue
          failure "SSH (#{local_user}): #{remote_user}@#{host}"
        end
      end
    end

    # Change credentials back to privileged user.
    Process.euid = 0
  end
end

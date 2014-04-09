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

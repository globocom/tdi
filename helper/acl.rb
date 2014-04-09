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

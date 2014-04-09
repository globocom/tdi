require 'fileutils'
require 'etc'

class TDIPlan < TDI
  def file(plan)
    plan.select { |key, val|
      val.is_a?(Hash)
    }.each_pair do |case_name, case_content|
      # Parse.
      path = case_name
      user = case_content['user']
      perm = case_content['perm']
      type = case_content['type']
      location = case_content['location']

      # Flag.
      @flag_success = true

      # Privileged user.
      begin
        Process.euid = 0
      rescue => e
        puts "ERR: Must run as root to change user credentials #{e}).".light_magenta
        exit 1
      end

      # Change credentials to local user.
      begin
        Process.euid = Etc.getpwnam(user).uid
      rescue => e
        puts "ERR: User \"#{user}\" not found (#{e}).".light_magenta
        exit 1
      end

      # Apply the test to a
      def testPerm filename, perm, type
        # Perm.
        begin
          FileUtils.touch(filename)
          @flag_success = false if perm.eql?('ro')
        rescue
          @flag_success = false if perm.eql?('rw')
        ensure
          # Cleanup, if type is directory (remove tempfile).
          FileUtils.rm(filename) if type.eql?('directory') rescue nil
        end
      end

      # Type.
      case type
      when 'directory'
        # Path.
        filename = "#{path}/#{ENV['HOSTNAME']}.rw"
        testPerm filename, perm, type
      when 'file'
        # Path.
        filename = path
        testPerm filename, perm, type
      when 'link'
          @flag_success = File.symlink?(path)
          @flag_success = File.exist?(path) if @flag_success
      else
        puts "ERR: Invalid file plan format \"#{type}\". Type must be \"directory\", \"file\" or \"link\".".light_magenta
        exit 1
      end

      # Location.
      unless type.eql?('directory')
        df_path = File.dirname(path)
      else
        df_path = path
      end
      fs_location_query_cmd = "df -P #{df_path} | tail -n 1 | awk '{print $1}'"
      device = `#{fs_location_query_cmd}`

      case location
      when 'local'
        @flag_success = false if device.include?(':')
      when 'nfs'
        @flag_success = false unless device.include?(':')
      else
        puts "ERR: Invalid file plan format \"#{location}\". Location must be \"local\" or \"nfs\".".light_magenta
        exit 1
      end

      # Verdict.
      if @flag_success
        success "FILE (#{user}): #{path} => #{perm} #{type} #{location}"
      else
        failure "FILE (#{user}): #{path} => #{perm} #{type} #{location}"
      end
    end

    # Change credentials back to privileged user.
    Process.euid = 0
  end
end

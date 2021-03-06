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

require 'fileutils'
require 'etc'
require 'sys/filesystem'
include Sys

REMOTE_FS_LIST = %w(cifs coda nfs nfs4 smbfs)

class TDIPlan < TDI
  def file(role_name, plan_name, plan_content)
    plan_content.select { |key, val|
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
        puts "ERR: Must run as root to change user credentials (#{e.message}).".light_magenta
        exit 1
      end

      # Change credentials to local user.
      begin
        Process.euid = Etc.getpwnam(user).uid
      rescue => e
        puts "ERR: User \"#{user}\" not found (#{e.message}).".light_magenta
        exit 1
      end

      # Apply permissions test.
      def testPerm filename, perm, type
        # Perm.
        begin
          FileUtils.touch(filename)
          @flag_success = false if perm.eql?('ro')
        rescue
          @flag_success = false if perm.eql?('rw')
        ensure
          # Cleanup. If type is directory, remove tempfile.
          if type.eql?('directory')
            FileUtils.rm(filename) rescue nil
          end
        end
      end

      # Type.
      case type
      when 'directory'
        # Access?
        # Must exist, be readable and executable.
        @flag_success = File.exist?(path) && File.readable?(path) && File.executable?(path)
        @flag_success = File.exist?(path) && File.readable?(path) && File.executable?(path) && File.writable?(path) if perm.eql?('rw')

        # Path.
        filename = "#{path}/#{ENV['HOSTNAME']}.rw"
        testPerm filename, perm, type if @flag_success # must be accessible or false positive may manifest
      when 'file'
        # Access?
        # Must exist and be readable.
        @flag_success = File.exist?(path) && File.readable?(path)
        @flag_success = File.exist?(path) && File.readable?(path) && File.writable?(path) if perm.eql?('rw')

        # Path.
        filename = path
        testPerm filename, perm, type if @flag_success # must be accessible or false positive may manifest
      when 'link'
        # Access?
        # Must exist and be readable. Target must also exist.
        @flag_success = File.symlink?(path) && File.exist?(path) && File.readable?(path)
        @flag_success = File.symlink?(path) && File.exist?(path) && File.readable?(path) && File.writable?(path) if perm.eql?('rw')
      else
        puts "ERR: Invalid file plan format \"#{type}\". Type must be \"directory\", \"file\" or \"link\".".light_magenta
        exit 1
      end

      # Location.
      if @flag_success
        mount_p = File.realpath(path)
        mount_t = nil
        while !mount_p.eql?('/') && mount_t.nil?
          mount_t = Filesystem.mounts.select { |mount| mount.mount_point.eql?(mount_p) }.first
          mount_t = mount_t.mount_type unless mount_t.nil?
          mount_p = File.expand_path("#{mount_p}/../") # pop leaf dir before next iteration
        end
        if mount_t.nil?
          mount_p = '/'
          mount_t = Filesystem.mounts.select { |mount| mount.mount_point.eql?(mount_p) }.first.mount_type
        end

        case location
        when 'local'
          @flag_success = false if REMOTE_FS_LIST.include?(mount_t)
        when 'nfs'
          @flag_success = false unless mount_t.eql?('nfs')
        else
          puts "ERR: Invalid file plan format \"#{location}\". Location must be \"local\" or \"nfs\".".light_magenta
          exit 1
        end
      end

      # Verdict.
      res_msg = "FILE (#{user}): #{path} => #{perm} #{type} #{location}"
      res_dict = {:path => case_name}.merge(case_content)
      if @flag_success
        success role_name, plan_name, res_msg, res_dict
      else
        failure role_name, plan_name, res_msg, res_dict
      end
    end

    # Change credentials back to privileged user.
    Process.euid = 0
  end
end

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

require 'net/http'
require 'net/https'
require 'timeout'
require 'uri'
require 'resolv'

class TDIPlan < TDI
  def _parse(uri, params)
    # Normalizing.
    if not uri =~ /^https?:\/\//
      uri = 'http://' + uri.to_s
    end

    # URI.
    _uri = URI(uri)
    ssl  = _uri.scheme.eql?('https')
    host = _uri.host
    port = _uri.port
    path = _uri.path.empty? ? '/' : _uri.path

    # Params.
    code = params['code'].nil? ? 200 : params['code'].to_i
    match = params['match']
    expect_header = params['expect_header']
    timeout_limit = params['timeout'].nil? ? 2 : params['timeout'].to_i

    if not params['proxy'].nil?
      proxy, proxy_port = params['proxy'].split(/:/)
      proxy_port = 3128 unless not proxy_port.nil?
    end

    if not params['expect_header'].nil?
      expect_header_key = params['expect_header'].split(':').first
      expect_header_value = nil
      if params['expect_header'].include?(':')
        expect_header_value = params['expect_header'][params['expect_header'].index(':')+1..-1].strip
      end
    end

    return host, port, path, proxy, proxy_port, code, match, expect_header_key, expect_header_value, ssl, timeout_limit
  end

  def http(role_name, plan_name, plan_content)
    plan_content.select { |key, val|
      val.is_a?(Hash)
    }.each_pair do |case_name, case_content|
      # Parse params.
      host, port, path, proxy, proxy_port, code, match, expect_header_key, expect_header_value, ssl, timeout_limit = _parse(case_name, case_content)

      # User.
      user = Etc.getpwuid(Process.euid).name

      # Initialize vars.
      host_addr = nil
      proxy_addr = nil
      res_str = case_name
      res_dict = {url: case_name}
      response = nil

      begin
        host_addr = Resolv.getaddress(host)

        if not proxy.nil? and not proxy_port.nil?
          proxy_addr = Resolv.getaddress(proxy)
          http = Net::HTTP::Proxy(proxy, proxy_port)
          timeout(timeout_limit) do
            begin
              http.start(host, port, use_ssl: ssl, verify_mode: OpenSSL::SSL::VERIFY_NONE) { |http|
                response = http.get(path)
              }
            rescue Errno::ECONNREFUSED, Errno::ECONNRESET => e
              res_msg = "HTTP (#{user}): #{res_str} (#{e.message})"
              warning role_name, plan_name, res_msg, res_dict
            end
          end

        else
          http = Net::HTTP.new(host, port)
          if ssl
            http.use_ssl = true
            http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          end
          timeout(timeout_limit) do
            begin
              http.start() { |http|
                response = http.get(path)
              }
            rescue Errno::ECONNREFUSED, Errno::ECONNRESET => e
              res_msg = "HTTP (#{user}): #{res_str} (#{e.message})"
              warning role_name, plan_name, res_msg, res_dict
            end
          end
        end
      rescue Timeout::Error => e
        res_msg = "HTTP (#{user}): #{res_str} (Timed out (#{timeout_limit}s) #{e.message})"
        failure role_name, plan_name, res_msg, res_dict
      rescue => e
        res_msg = "HTTP (#{user}): #{res_str} (#{e.message})"
        failure role_name, plan_name, res_msg, res_dict
      end

      if not response.nil?
        if not match.nil? and not response.body.chomp.include?(match.chomp)
          res_msg = "HTTP (#{user}): #{res_str} (Expect string '#{match.chomp}')"
          failure role_name, plan_name, res_msg, res_dict
        elsif not expect_header_key.nil? and not expect_header_value.nil? and not response[expect_header_key].eql?(expect_header_value)
          res_msg = "HTTP (#{user}): #{res_str} (Expect header with content '#{expect_header_key}: #{expect_header_value}')"
          failure role_name, plan_name, res_msg, res_dict
        elsif not expect_header_key.nil? and response[expect_header_key].nil?
          res_msg = "HTTP (#{user}): #{res_str} (Expect header '#{expect_header_key}')"
          failure role_name, plan_name, res_msg, res_dict
        elsif not code.nil? and (response.code.to_i != code)
          res_msg = "HTTP (#{user}): #{res_str} (Expect HTTP response code #{code})"
          failure role_name, plan_name, res_msg, res_dict
        else
          res_msg = "HTTP (#{user}): #{res_str}"
          success role_name, plan_name, res_msg, res_dict
        end
      end
    end
  end
end

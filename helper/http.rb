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
require "net/https"
require 'timeout'
require 'uri'
require 'resolv'

class TDIPlan < TDI

  def _parse(uri,params)

    # Normalizing
    if not uri =~ /^https?:\/\//
        uri = 'http://' + uri.to_s
    end

    # URI
    _uri = URI(uri)
    ssl  = _uri.scheme.eql?("https")
    host = _uri.host
    port = _uri.port
    path = _uri.path.empty? ? '/' : _uri.path

    # Params
    code = params['code'].nil? ? 200 : params['code'].to_i
    match = params['match']
    expect_header = params['expect_header']
    timeout_limit = params['timeout'].nil? ? 2 : params['timeout'].to_i

    if not params['proxy'].nil?
        proxy_addr, proxy_port = params['proxy'].split(/:/)
        proxy_port = 3128 unless not proxy_port.nil?
    end

    if not params['expect_header'].nil?
        expect_header_key = params['expect_header'].split(':').first
        expect_header_value = nil
        if params['expect_header'].include?(':')
            expect_header_value = params['expect_header'][params['expect_header'].index(':')+1..-1].strip
        end
    end

    return host, port, path, proxy_addr, proxy_port, code, match, expect_header_key, expect_header_value, ssl, timeout_limit
  end

  def http(plan)
    plan.select { |key, val|
      val.is_a?(Hash)
    }.each_pair do |case_name,case_content|

      host, port, path, proxy_addr, proxy_port, code, match, expect_header_key, expect_header_value, ssl, timeout_limit = _parse(case_name,case_content)

      # User
      user = Etc.getpwuid(Process.euid).name

      response = nil

      if not proxy_addr.nil? and not proxy_port.nil?
        begin
          Resolv.getaddress(proxy_addr)
          http = Net::HTTP::Proxy(proxy_addr, proxy_port)

          timeout(timeout_limit) do
            begin
              Resolv.getaddress(host)
              http.start(host,port,:use_ssl => ssl, :verify_mode => OpenSSL::SSL::VERIFY_NONE) { |http|
                response = http.get(path)
              }
            rescue Errno::ECONNREFUSED, Errno::ECONNRESET
              warning "HTTP (#{user}): #{case_name} - Connection reset or refused."
            end
          end
        rescue Resolv::ResolvError => re
          failure "HTTP (#{user}): #{re.message}"
        rescue Resolv::ResolvTimeout => rt
          failure "HTTP (#{user}): #{rt.message}"
        rescue Timeout::Error
          failure "HTTP (#{user}): #{case_name} - Timed out (#{timeout_limit}s)."
        end

      else
        begin
          Resolv.getaddress(host)
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
            rescue Errno::ECONNREFUSED, Errno::ECONNRESET
              warning "HTTP (#{user}): #{case_name} - Connection reset or refused."
            end
          end
        rescue Resolv::ResolvError => re
          failure "HTTP (#{user}): #{re.message}"
        rescue Resolv::ResolvTimeout => rt
          failure "HTTP (#{user}): #{rt.message}"
        rescue Timeout::Error
          failure "HTTP (#{user}): #{case_name} - Timed out."
        end
      end

      if not response.nil?
          if not match.nil? and not response.body.chomp.include?(match.chomp)
            failure "HTTP (#{user}): #{case_name} - Expected string '#{match.chomp}'"
          elsif not expect_header_key.nil? and not expect_header_value.nil? and not response[expect_header_key].eql?(expect_header_value)
            failure "HTTP (#{user}): #{case_name} - Expected header with content '#{expect_header_key}: #{expect_header_value}'"
          elsif not expect_header_key.nil? and response[expect_header_key].nil?
            failure "HTTP (#{user}): #{case_name} - Expected header '#{expect_header_key}'"
          elsif not code.nil? and (response.code.to_i != code)
            failure "HTTP (#{user}): #{case_name} - Expected HTTP #{code}"
          else
            success "HTTP (#{user}): #{case_name}"
          end
      end
    end
  end
end

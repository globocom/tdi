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

require 'net/http'
require 'net/https'
require 'timeout'
require 'uri'
require 'resolv'

class TDIPlan < TDI

  def _parse(uri, params)
    # Normalizing
    unless uri =~ /^https?:\/\//
      uri = 'http://' + uri.to_s
    end

    # URI
    _uri = URI(uri)
    ssl = _uri.scheme.eql?('https')

    # Params to be sent
    headers = params['headers']
    headers = headers.first unless headers.nil?
    unless params['proxy'].nil?
      proxy_addr, proxy_port = params['proxy'].split(':')
      proxy_port = 3128 unless not proxy_port.nil?
    end

    # Params to be checked
    code = params['code'].nil? ? 200 : params['code'].to_i
    match = params['match'].nil? ? nil : Regexp.new(params['match'])
    match_headers = params['match_headers']
    match_headers = match_headers.first unless match_headers.nil?
    unless match_headers.nil?
      match_headers.each do |k, v|
        match_headers[k] = Regexp.new(v) unless v.nil?
      end
    end
    timeout_limit = params['timeout'].nil? ? 2 : params['timeout'].to_i

    return ssl, headers, proxy_addr, proxy_port, code, match, match_headers, timeout_limit
  end

  def http(plan)
    plan.select { |key, val|
      val.is_a?(Hash)
    }.each_pair do |case_name, case_content|

      ssl, headers, proxy_addr, proxy_port, code, match, match_headers, timeout_limit = _parse(case_name, case_content)

      uri = URI(case_name)

      # User
      user = Etc.getpwuid(Process.euid).name

      response = nil

      unless proxy_addr.nil? and not proxy_port.nil?
        http = Net::HTTP::Proxy(proxy_addr, proxy_port)
      else
        http = Net::HTTP.new(uri.host, uri.port)
      end

      begin
        # Check for name resolution
        Resolv.getaddress(proxy_addr) unless proxy_addr.nil?
        Resolv.getaddress(uri.host)

        req = Net::HTTP::Get.new(uri)
        headers.each { |k, v| req[k] = v } unless headers.nil?

        timeout(timeout_limit) do
          begin
            http.start(uri.host, uri.port, :use_ssl => ssl, :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|
              response = http.request(req)
            end
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

      unless response.nil?
        @case_passed = true

        unless match_headers.nil?
          match_headers.each do |k, v|
            if v.nil?
              if response[k].nil?
                failure "HTTP (#{user}): #{case_name} - Expected header '#{k}'"
              end
            else
              unless v.match(response[k])
                failure "HTTP (#{user}): #{case_name} - Expected header '#{k}: #{v.source}'"
              end
            end
          end
        end

        unless match.nil?
          unless match.match(response.body)
            failure "HTTP (#{user}): #{case_name} - Expected content '#{match.source}'"
          end
        end

        if response.code.to_i != code
          failure "HTTP (#{user}): #{case_name} - Expected HTTP #{code}"
        end

        success "HTTP (#{user}): #{case_name}" if self.case_passed?
      end
    end
  end
end

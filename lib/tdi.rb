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

require 'socket'
require_relative 'tdi/version'

class TDI
  attr_accessor :plan_passed, :case_passed
  alias :plan_passed? :plan_passed
  alias :case_passed? :case_passed
  attr_accessor :skip, :pass, :warn, :fail, :report

  def initialize
    @plan_passed = true
    @case_passed = true
    @skip = 0
    @pass = 0
    @warn = 0
    @fail = 0
    @report = {hostname: Socket.gethostname}
  end

  def update_report(status, role_name, plan_name, res_dict)
    @report[role_name] = {} unless @report.has_key?(role_name)
    @report[role_name][plan_name] = [] unless @report[role_name].has_key?(plan_name)
    res_dict[:status] = status
    @report[role_name][plan_name] << res_dict
  end

  def success(role_name, plan_name, res_msg, res_dict)
    update_report(:pass, role_name, plan_name, res_dict)
    # I like the seventies.
    printf("%-70s [ %s ]\n", res_msg, 'PASS'.light_green)
    @pass += 1
  end

  def warning(role_name, plan_name, res_msg, res_dict)
    update_report(:warn, role_name, plan_name, res_dict)
    printf("%-70s [ %s ]\n", res_msg, 'WARN'.light_yellow)
    @warn += 1
  end

  def failure(role_name, plan_name, res_msg, res_dict)
    update_report(:fail, role_name, plan_name, res_dict)
    printf("%-70s [ %s ]\n", res_msg, 'FAIL'.light_red)
    @plan_passed = false
    @case_passed = false
    @fail += 1
  end

  def total
    @skip + @pass + @warn + @fail
  end
end

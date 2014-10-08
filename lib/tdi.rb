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

require_relative 'tdi/version'

class TDI
  attr_accessor :passed
  alias :passed? :passed
  attr_accessor :skip, :pass, :warn, :fail

  def initialize
    @passed = true
    @skip = 0
    @pass = 0
    @warn = 0
    @fail = 0
  end

  def success(msg)
    # I like the seventies.
    printf('%-70s', msg)
    puts ' [ ' + 'PASS'.light_green + ' ]'
    @pass += 1
  end

  def warning(msg)
    printf('%-70s', msg)
    puts ' [ ' + 'WARN'.light_yellow + ' ]'
    @warn += 1
  end

  def failure(msg)
    printf('%-70s', msg)
    puts ' [ ' + 'FAIL'.light_red + ' ]'
    @passed = false
    @fail += 1
  end

  def total
    @skip + @pass + @warn + @fail
  end
end

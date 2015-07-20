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

module HashRecursiveMerge
  def rmerge(other_hash)
    r = {}

    merge(other_hash) do |key, oldval, newval|
      r[key] = oldval.is_a?(Hash) ? oldval.rmerge(newval) : newval
    end
  end

  def rmerge!(other_hash)
    merge!(other_hash) do |key, oldval, newval|
      oldval.is_a?(Hash) ? oldval.rmerge!(newval) : newval
    end
  end
end

class Hash
  include HashRecursiveMerge
end

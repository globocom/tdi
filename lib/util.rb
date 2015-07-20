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

require 'awesome_print'

# Awesome Print config
def a_p obj
  ap obj, {
    indent: 2,
    index: false,
    color: {
      args:       :pale,
      array:      :white,
      bigdecimal: :blue,
      class:      :yellow,
      date:       :greenish,
      falseclass: :red,
      fixnum:     :blue,
      float:      :blue,
      hash:       :blue,
      keyword:    :cyan,
      method:     :purpleish,
      nilclass:   :red,
      rational:   :blue,
      string:     :green,
      struct:     :pale,
      symbol:     :cyanish,
      time:       :greenish,
      trueclass:  :green,
      variable:   :cyanish,
    }
  }
end

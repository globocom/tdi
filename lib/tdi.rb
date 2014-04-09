require 'tdi/version'

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

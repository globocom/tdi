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

require_relative 'tdi'

# Run tests.
def runner(opts, filename, plan)
  puts 'Running tests...'.cyan if opts[:verbose] > 1

  # Skip reserved roles.
  # Ex: {"global": {"desc": "...", "acl": {"domain1": {"port": 80}...}...}...}
  # Ex: {"common": {"desc": "...", "acl": {"domain1": {"port": 80}...}...}...}
  plan.select { |role_name, role_content|
    if role_content.is_a?(Hash)
      UNTESTABLE_ROLE_LIST.include?(role_name) or role_content['notest'].eql?('true')
    end
  }.each_pair do |role_name, role_content|
    puts "Skipping reserved or disabled role: #{role_name}".yellow if opts[:verbose] > 0
  end

  # Remove untestable roles.
  plan.reject! { |role_name, role_content|
    if role_content.is_a?(Hash)
      UNTESTABLE_ROLE_LIST.include?(role_name) or role_content['notest'].eql?('true')
    end
  }
  total_roles = plan.select { |key, val| val.is_a?(Hash) }.size
  puts "Total roles to run: #{total_roles}".cyan if opts[:verbose] > 1

  # Run the rest.
  tdiplan = TDIPlan.new

  # Role.
  # Ex: {"admin": {"desc": "...", "acl": {"domain1": {"port": 80}...}...}...}
  plan.select { |key, val|
    val.is_a?(Hash)
  }.each_with_index do |(role_name, role_content), index|
    total_plans = role_content.select { |key, val| val.is_a?(Hash) }.size

    if role_content['desc'].nil?
      puts "* #{role_name.capitalize}".cyan
    else
      puts "* #{role_name.capitalize} - #{role_content['desc']}".cyan
    end
#    puts "Running tests for role: #{role_name}".cyan if opts[:verbose] > 0
    puts "Total test plans to run for this role: #{total_plans}".cyan if opts[:verbose] > 1

    # Test plan.
    # Ex: {"acl": {"domain1": {"port": 80}...}...}
    role_content.select { |key, val|
      val.is_a?(Hash)
    }.each_pair do |plan_name, plan_content|
      total_cases = plan_content.select { |key, val| val.is_a?(Hash) }.size

      puts "* #{plan_name.upcase}".cyan
#      puts "Test plan: #{role_name}::#{plan_name}".cyan if opts[:verbose] > 0
      puts "Total test cases to run for this plan: #{total_cases}".cyan if opts[:verbose] > 1

      if opts[:verbose] > 3
        puts "Plan: #{plan_name}"
        puts 'Plan content:'
        puts "* #{plan_content}".yellow
      end

      # Test plan content (test cases).
      # Ex: {"domain1": {"port": 80}, "domain2": {"port": 80}...}
      if tdiplan.respond_to?(plan_name)
        tdiplan.send(plan_name, plan_content)
      else
        puts "Skipping not supported test plan type \"#{plan_name}\" for \"#{role_name}::#{plan_name}\".".yellow
        tdiplan.skip = tdiplan.skip + total_cases
      end
    end

    puts unless index == plan.size - 1
  end

  # Summary.
  summary(opts, tdiplan)

  # Shred.
  if opts.shred?
    puts "Shreding and removing test plan file: \"#{filename}\"...".cyan if opts[:verbose] > 2
    if system("shred -f -n 38 -u -z #{filename}")
      puts "Shreding and removing test plan file: \"#{filename}\"... done.".green if opts[:verbose] > 2
    else
      puts "ERR: Shreding and removing test plan file: \"#{filename}\".".light_magenta
    end
  end

  puts 'Running tests... done.'.green if opts[:verbose] > 1

  ret = tdiplan.passed? ? 0 : 1
  ret = 0 if opts.nofail?
  ret
end

# Display test summary.
def summary(opts, tdiplan)
  puts '=' * 79
  puts "Total: #{tdiplan.total}  |  Skip: #{tdiplan.skip}  |  Pass: #{tdiplan.pass}  |  Warn: #{tdiplan.warn}  |  Fail: #{tdiplan.fail}"
end

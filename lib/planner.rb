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

require_relative 'rblank'
require_relative 'rmerge'

# Test plan builder.
def planner(opts, plan)
  # Compila um plano completo.
  # Processa a herança.
  # Compila novamente para gerar um plano intermediário.
  #
  # Pass 1.
  if opts[:verbose] > 1
    puts '* Pass 1...'.cyan
    puts
  end
  compiled_plan1 = plan_compiler(opts, plan)
  inherited_plan1 = plan_inheriter(opts, compiled_plan1)
  recompiled_plan1 = plan_compiler(opts, inherited_plan1)
  if opts[:verbose] > 1
    puts '* Pass 1... done.'.green
    puts
  end

  # Zera o plano, mantendo apenas a estrutura de hashes. Desta forma é possível
  # gerar um esqueleto de plano com todas as entradas de test cases com valores
  # vazios (originais e herdados).
  # Logo em seguida ocorre um merge recursivo com os valores originais para
  # depois ser processado por completo novamente.
  # O objetivo é dar precedência aos valores globais locais sobre os valores
  # herdados.
  #
  # Blank and repopulate with original values.
  blanked_plan = recompiled_plan1.rblank
  if opts[:verbose] > 2
    puts 'Blanked plan:'
    puts "* #{blanked_plan}".yellow
  end

  repopulated_plan = blanked_plan.rmerge(compiled_plan1)
  if opts[:verbose] > 2
    puts 'Repopulated plan:'
    puts "* #{repopulated_plan}".yellow
  end

  # Compila um plano completo.
  # Processa a herança.
  # Compila novamente para gerar um plano final.
  #
  # Pass 2.
  if opts[:verbose] > 1
    puts '* Pass 2...'.cyan
    puts
  end
  compiled_plan2 = plan_compiler(opts, repopulated_plan)
  inherited_plan2 = plan_inheriter(opts, compiled_plan2)
  recompiled_plan2 = plan_compiler(opts, inherited_plan2)
  if opts[:verbose] > 1
    puts '* Pass 2... done.'.green
    puts
  end

  # Final plan.
  plan_filter(opts, recompiled_plan2)
end

# Test plan compile.
def plan_compiler(opts, plan)
  # Gera um plano de teste baseado em todos os valores dos hashes, desde o mais
  # global (role) até o mais específico (test case).
  # Ordem de precedência: test case > test plan.

  puts 'Compiling test plan...'.cyan if opts[:verbose] > 1

  compiled_plan = {}

  # Role.
  # Ex: {"app": {"desc": "...", "acl": {"domain1": {"port": 80}...}...}...}
  plan.select { |key, val|
    val.is_a?(Hash)
  }.each_with_index do |(role_name, role_content), index|
    if opts[:verbose] > 2
      puts '=' * 60
      puts "Role: #{role_name}"
      puts 'Role content:'
      puts "* #{role_content}".yellow
    end

    # Role (if not already).
    compiled_plan[role_name] ||= role_content

    # Test plan.
    # Ex: {"acl": {"domain1": {"port": 80}...}...}
    role_content.select { |key, val|
      val.is_a?(Hash)
    }.each_pair do |plan_name, plan_content|
      if opts[:verbose] > 2
        puts "Plan: #{plan_name}"
        puts 'Plan content:'
        puts "* #{plan_content}".yellow
      end

      # Test plan (if not already).
      compiled_plan[role_name][plan_name] ||= plan_content

      # Test case.
      # Ex: {"domain1": {"port": 80}...}
      plan_content.select { |key, val|
        val.is_a?(Hash)
      }.each_pair do |case_name, case_content|
        if opts[:verbose] > 2
          puts "Case: #{case_name}"
          puts 'Case content:'
          puts "* #{case_content}".yellow
        end

        # Test case compile.
        new_case_content = role_content.reject { |key, val| UNMERGEABLE_KEY_LIST.include?(key) || val.is_a?(Hash) }
        new_case_content.merge!(plan_content.reject { |key, val| UNMERGEABLE_KEY_LIST.include?(key) || val.is_a?(Hash) })
        new_case_content.merge!(case_content.reject { |key, val| UNMERGEABLE_KEY_LIST.include?(key) || val.is_a?(Hash) })

        # Test case (new, merged).
        compiled_plan[role_name][plan_name][case_name] = new_case_content

        if opts[:verbose] > 2
          puts 'Compiled case content:'
          puts "* #{new_case_content}".yellow
        end
      end
    end

    if opts[:verbose] > 2
      puts '=' * 60
      puts unless index == plan.size - 1
    end
  end

  if opts[:verbose] > 1
    puts 'Compiling test plan... done.'.green
    puts
  end

  compiled_plan
end

# Poor's man test plan inheritance.
def plan_inheriter(opts, plan)
  # Processa a herança entre roles e test plans.

  puts 'Inheriting test plan...'.cyan if opts[:verbose] > 1

  inherited_plan = {}

  # Role may inherit from role.
  # Ex: {"app": {"desc": "...", "inherits": "other_role", "acl": {"domain1": {"port": 80}...}...}...}
  plan.select { |key, val|
    val.is_a?(Hash)
  }.each_with_index do |(role_name, role_content), index|
    if opts[:verbose] > 2
      puts '=' * 60
      puts "Role: #{role_name}"
      puts 'Role content:'
      puts "* #{role_content}".yellow
    end

    # Role (if not already).
    inherited_plan[role_name] ||= role_content

    # Inheritance present?
    i_role_name = role_content['inherits']
    unless i_role_name.nil?
      puts "Role #{role_name} inherits #{i_role_name}" if opts[:verbose] > 2
      inherited_plan[role_name] = plan[i_role_name].rmerge(role_content)
    end

    # Plan may inherit from plan.
    # Ex: {"acl": {"inherits": "other_role::other_plan", "domain1": {"port": 80}...}...}
    role_content.select { |key, val|
      val.is_a?(Hash)
    }.each_pair do |plan_name, plan_content|
      if opts[:verbose] > 2
        puts "Plan: #{plan_name}"
        puts 'Plan content:'
        puts "* #{plan_content}".yellow
      end

      # Test plan (if not already).
      inherited_plan[role_name][plan_name] ||= plan_content

      # Inheritance present?
      i_plan = plan_content['inherits']
      unless i_plan.nil?
        i_role_name, i_plan_name = role_plan_split(i_plan)

        if i_role_name.nil? || i_plan_name.nil?
          puts "ERR: Invalid inheritance \"#{i_plan}\". Must match pattern \"role::plan\".".light_magenta
          exit 1
        end

        # TODO: Tratar quando chave não existe.
        puts "Plan #{plan_name} inherits #{i_plan}" if opts[:verbose] > 2
        inherited_plan[role_name][plan_name] = plan[i_role_name][i_plan_name].rmerge(plan_content)
      end
    end

    if opts[:verbose] > 2
      puts '=' * 60
      puts unless index == plan.size - 1
    end
  end

  if opts[:verbose] > 1
    puts 'Inheriting test plan... done.'.green
    puts
  end

  inherited_plan
end

# Test plan filter.
def plan_filter(opts, plan)
  # Filtra roles e test plans desejados a partir do plano fornecido.

  puts 'Filtering test plan...'.cyan if opts[:verbose] > 1

  filtered_plan = {}
  flag_err = false

  # Ex: -p admin
  # Ex: -p admin::acl
  # Ex: --plan app
  # Ex: --plan app::acl
  # Ex: --plan fe
  # Ex: --plan admin::acl,app,fe
  if opts.plan?
    # Do filter.
    puts 'Filtering following test plan from input file:'.cyan if opts[:verbose] > 0
    opts[:plan].each do |plan_name|
      puts "  - #{plan_name}".cyan if opts[:verbose] > 0

      # Pattern from command line is already validate by validate_args().
      # Does not need to check for nil.
      f_role_name, f_plan_name = role_plan_split(plan_name)

      if plan.has_key?(f_role_name)
        unless f_plan_name.nil?
          # Test plan only.
          if plan[f_role_name].has_key?(f_plan_name)
            # Initialize hash key if not present.
            filtered_plan[f_role_name] ||= {}
            filtered_plan[f_role_name][f_plan_name] = plan[f_role_name][f_plan_name]
            puts "    Test plan \"#{plan_name}\" included.".green if opts[:verbose] > 0
          else
            puts "ERR: Test plan \"#{plan_name}\" not found in input file. This test plan can not be included.".light_magenta
            flag_err = true
          end
        else
          # Role test plan (entire).
          filtered_plan[f_role_name] = plan[f_role_name]
          puts "    Role \"#{plan_name}\" included.".green if opts[:verbose] > 0
        end
      else
        puts "ERR: Role \"#{f_role_name}\" not found in input file. Test plan \"#{plan_name}\" can not be included.".light_magenta
        flag_err = true
      end
    end

    puts if opts[:verbose] > 0
  else
    # No filter.
    filtered_plan = plan
  end

  if opts[:verbose] > 2
    puts 'Filtered test plan:'.cyan
    puts "* #{filtered_plan}".yellow
  end

  exit 1 if flag_err

  if opts[:verbose] > 1
    puts 'Filtering test plan... done.'.green
    puts
  end

  filtered_plan
end

# Split role_name and plan_name.
def role_plan_split(name)
  if name.include?('::')
    # Test plan only.
    f_role_name = name.split('::').first
    f_plan_name = name.split('::').last
  else
    # Role test plan (entire).
    f_role_name = name
    f_plan_name = nil
  end

  return f_role_name, f_plan_name
end

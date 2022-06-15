require 'tenant_command/tenant_copy_subcommand'

class TenantCommand < Cri::CommandRunner
  include ThreeScaleToolbox::Command

  def self.command
    Cri::Command.define do
      name        'tenant'
      usage       'tenant <sub-command> [options]'
      summary     '3scale tenant command'
      description '3scale tenant command'
      
      run do |_opts, _args, cmd|
        puts cmd.help
      end
    end
  end
  add_subcommand(TenantCopySubcommand)
end
ThreeScaleToolbox::CLI.add_command(TenantCommand)

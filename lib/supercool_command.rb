class SupercoolCommand < Cri::CommandRunner
  include ThreeScaleToolbox::Command

  def self.command
    Cri::Command.define do
      name        'supercool'
      usage       'supercool [options]'
      summary     '3scale supercool'
      description '3scale supercool command'
      runner SupercoolCommand
    end
  end

  def run
    puts 'Doing lots of super things very well!'
  end
end
ThreeScaleToolbox::CLI.add_command(SupercoolCommand)

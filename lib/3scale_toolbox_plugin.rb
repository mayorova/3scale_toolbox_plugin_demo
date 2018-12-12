class SupercoolCommand < Cri::CommandRunner
  include ThreeScaleToolbox::Command

  def self.command
    Cri::Command.define do
      name        'foo'
      usage       'foo [options]'
      summary     '3scale foo'
      description '3scale foo command'
      runner SupercoolCommand
    end
  end

  def run
    puts 'Doing lots of things!'
  end
end
ThreeScaleToolbox::CLI.add_command(SupercoolCommand)

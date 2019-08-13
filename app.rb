$LOAD_PATH << 'lib'

require 'alfred_workflow'
require 'ssh'

class App

  def initialize
    @ssh = SSH.new
  end

  def sub_command(command_name)
    instance_variable_get("@#{command_name}")
  end

  class << self
    def run(command, *args)
      App.new.sub_command(command).run(*args)
    end
  end
end

App.run(*ARGV)

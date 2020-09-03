require 'fuzzy'
require 'json'

class SSH
  class ITerm2
    attr_accessor :tab_id, :command, :host

    def initialize(options)
      @tab_id = options['tab_id']
      @command = options['command']
      if @command.include?(' nc ')
        process = Process.find_by_pid(options['pid'].to_s)
        @host = Process.find_by_pid(process.ppid).host
      else
        @host = @command.scan(/\S+/)[1]&.delete("\\")
      end
    end

    class << self
      def get_tab_commands
        @tab_commands ||= JSON.parse(`curl -s http://localhost:28082 -d "get_tab_commands()"`).each_with_object({}) { |t, result|
          tab = new(t)
          result[tab.host] = tab
        }
      end
    end
  end

  # Depracated
  class Process

    attr_accessor :uid, :pid, :ppid, :tty, :name, :host

    def initialize(process_info_line)
      options = parse_process_info(process_info_line)
      @uid = options[:uid]
      @pid = options[:pid]
      @ppid = options[:ppid]
      @tty = options[:tty]
      @name = options[:name]
      @host = options[:host]
    end

    def parse_process_info(process_info_line)
      result = %i[uid pid ppid tty name].zip(process_info_line.split(' ', 5)).to_h
      result[:host] = result[:name].scan(/\S+$/).first
      result
    end

    def ssh?
      name =~ /ssh /
    end

    def login_zsh?
      name =~ /-zsh/
    end

    class << self
      def all_processes
        @all_processes ||= all_system_processes.each_with_object({}) do |(pid, process), result|
          next unless process.ssh?
          parent = find_by_pid(process.ppid)
          next unless parent || !parent.login_zsh?
          result[process.host] = process
        end
      end

      def all_system_processes
        @all_system_processes ||= `ps -o uid,pid,ppid,tty,command`.lines.each_with_object({}) do |line, result|
          process = new(line)
          result[process.pid] = process
        end
      end

      def find_by_pid(pid)
        all_system_processes[pid]
      end
    end
  end

  class Config

    attr_accessor :host, :iterm2_tab

    def initialize(host)
      @host = host
    end

    def iterm2_tab
      @iterm2_tab ||= ITerm2.get_tab_commands[host]
    end

    def status
      @status ||= iterm2_tab ? 'on' : 'off'
    end

    def icon
      "#{status}.png"
    end

    def alfred_subtitle
      @host
    end

    def alfred_arg
      tab = iterm2_tab ? iterm2_tab.tab_id : ''
      "ssh #{status == 'on' ? 'show' : 'start'} #{@host} #{tab}"
    end

    class << self
      def all
        @all ||= IO.readlines(File.expand_path('~/.ssh/config')).grep(/^\s*Host\s+/).flat_map do |line|
          line.sub!(/^\s*Host\s+/, '')
          line.split(/\s+/).map do |host|
            new(host)
          end
        end
      end

      def find_by_host(host)
        all.find { |t| t.host == host }
      end

      def select_by_host(host)
        if host.nil? || host.empty?
          all
        else
          all.select { |t| t.host.fuzzy_matches?(host) }
        end
      end
    end
  end

  def list(*args)
    print Config.select_by_host(args[0].strip).sort_by(&:status).reverse.each_with_object(Alfred::Workflow.new) { |config, workflow|
      workflow.result
        .uid(config.host)
        .title(config.host)
        .subtitle(config.alfred_subtitle)
        .icon(config.icon)
        .arg(config.alfred_arg)
    }.output
  end

  def start(host, *args)
    system <<-EOF
    curl -s http://127.0.0.1:28082 -d "run_ssh(host: \\"#{host}\\")" &> /dev/null
    EOF
  end

  def show(host, tab_id)
    system <<-EOF
    curl -s http://127.0.0.1:28082 -d "activate_tab_by_id(tab_id: \\"#{tab_id}\\")" &> /dev/null
    EOF
  end

  def run(command, *args)
    send(command, *args)
  end
end

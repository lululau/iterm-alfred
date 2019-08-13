require 'fuzzy'

class SSH
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

    attr_accessor :host

    def initialize(host)
      @host = host
    end

    def status
      SSH::Process.all_processes[host] ? 'on' : 'off'
    end

    def icon
      "#{status}.png"
    end

    def alfred_subtitle
      @host
    end

    def alfred_arg
      "start #{@host}"
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
    print Config.select_by_host(args[0].strip).each_with_object(Alfred::Workflow.new) { |config, workflow|
      workflow.result
        .uid(config.host)
        .title(config.host)
        .subtitle(config.alfred_subtitle)
        .icon(config.icon)
        .arg(config.alfred_arg)
    }.output
  end

  def start(args)
    puts Config.find_by_host(args[0]).start!
  end

  def run(command, *args)
    send(command, *args)
  end
end

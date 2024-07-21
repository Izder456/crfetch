require "process"
require "option_parser"

module Manip
  def self.bytesToMebibytes(bytes : String) : String
    # Implement turning bytes into Mebibytes
    mebibyte = 1048576
    bytes = bytes.strip.to_f / mebibyte

    "%.2f" % bytes
  end
end

module Resource
  def self.runSysCommand(command : String) : String
    # Implement running system command and yoinking output via channels
    channel = Channel(String).new
    # Spawn a fiber to communicate on the channel.
    spawn do
      output = IO::Memory.new
      Process.run(command, shell: true, output: output)
      output.close
      channel.send(output.to_s)
    end
    channel.receive
  end

  def self.getPlatform : String?
    # Implement getting system platform
    case os = self.runSysCommand("uname").strip
    when /Linux/
      match = runSysCommand("grep PRETTY_NAME /etc/os-release | cut -d = -f 2")
      "Linux #{match}"
    when /FreeBSD/
      "FreeBSD"
    when /OpenBSD/
      "OpenBSD"
    when /NetBSD/
      "NetBSD"
    else
      "Unsupported OS"
    end
  end

  def self.getRelease : String?
    # Implement Getting Release Version
    self.runSysCommand("uname -r").strip
  end

  def self.getUser : String?
    # Implement Getting Username
    self.runSysCommand("whoami").strip
  end

  def self.getMemory : String?
    # Implement Getting Memory Usage
    os = getPlatform
    case os
    when /Linux/
      memory = self.runSysCommand("free -b | awk '/Mem/ {print $2}'").strip
    when /BSD/
      memory = self.runSysCommand("sysctl -n hw.physmem").strip
    else
      memory = ""
    end

    Manip.bytesToMebibytes(memory)
  end

  def self.getMemoryUsage : String?
    # Implement getting memory usage
    os = getPlatform
    case os
    when /Linux/
      used_memory = runSysCommand("free -b | awk '/Mem/ {print $3}'").strip
    when /BSD/
      used_memory = runSysCommand("vmstat -s | awk '/pages active/ {printf \"%.2f\\n\", $1*4096}'").strip
    else
      used_memory = ""
    end

    Manip.bytesToMebibytes(used_memory)
  end

  def self.getCpu : String?
    # Implement Getting CPU name
    os = getPlatform
    case os
    when /Linux/
      cpu_info = runSysCommand("lscpu | grep 'Model name'| cut -d : -f 2 | awk '{$1=$1}1'").strip
    when /BSD/
      cpu_info = runSysCommand("sysctl -n hw.model").strip
    else
      nil
    end
  end
end

module OptionHandler
  class Options
    property lowercase : Bool
    property color : Int32

    def initialize
      @lowercase = false
      @color = 3 # Default blue
    end
  end

  # Inherit Exception class
  class OptionError < Exception end

  def self.parse : Options
    options = Options.new

    begin
      OptionParser.parse do |parser|
        parser.on "-l", "--lowercase", "Use lowercase labels" do
          options.lowercase = true
        end

        parser.on "-c COLOR", "--color COLOR", "Pick a color output (0-7)" do |c|
          color = c.to_i?
          if color.nil? || color < 0 || color > 7
            raise OptionError.new("Invalid color. Please choose a value between 0 and 7.")
          end
          options.color = color
        end

        parser.on "-h", "--help", "Show help" do
          puts self.help_message
          exit
        end

        parser.invalid_option do |flag|
          raise OptionError.new("Invalid option: #{flag}")
        end

        parser.missing_option do |flag|
          raise OptionError.new("Missing value for option: #{flag}")
        end
      end
    rescue error : OptionError
      STDERR.puts "Error: #{error.message}"
      exit(1)
    rescue error : OptionParser::InvalidOption
      STDERR.puts "Error: Invalid option"
      exit(1)
    rescue error : OptionParser::MissingOption
      STDERR.puts "Error: Missing option"
      exit(1)
    end

    options
  end

  def self.help_message : String
    colors = [
      "\e[31m0\e[0m", # red
      "\e[32m1\e[0m", # green
      "\e[33m2\e[0m", # yellow
      "\e[34m3\e[0m", # blue
      "\e[35m4\e[0m", # magenta
      "\e[36m5\e[0m", # cyan
      "\e[37m6\e[0m", # white
      "\e[30m7\e[0m"  # black
    ]

    <<-HELP
    Usage: crfetch [options]
    -l, --lowercase                    Use lowercase labels
    -c, --color COLOR                  Pick a color output (0-7)
                                       #{colors.join(" ")}
    -h, --help                         Show help
    HELP
  end
end

module Main
  def self.run
    options = OptionHandler.parse

    # get resources
    user = Resource.getUser
    os = Resource.getPlatform
    release = Resource.getRelease
    cpu = Resource.getCpu
    mem_usage = Resource.getMemoryUsage
    mem = Resource.getMemory

    # variables for formatting
    ## styles
    bold = "\e[1m"
    reset = "\e[0m"
    ## colors
    colors = [
      "\e[31m", # red
      "\e[32m", # green
      "\e[33m", # yellow
      "\e[34m", # blue
      "\e[35m", # magenta
      "\e[36m", # cyan
      "\e[37m", # white
      "\e[30m"  # black
    ]
    # labels
    label = [
      "USER",
      "OS",
      "VER",
      "CPU",
      "MEM"
    ]

    label = label.map(&.downcase) if options.lowercase

    # output
    puts "#{colors[options.color]}    ,    #{reset}#{bold}#{label[0]}#{reset}: #{user}"
    puts "#{colors[options.color]}   / \\   #{reset}#{bold}#{label[1]}#{reset}:   #{os}"
    puts "#{colors[options.color]}  /   \\  #{reset}#{bold}#{label[2]}#{reset}:  #{release}"
    puts "#{colors[options.color]} |     | #{reset}#{bold}#{label[3]}#{reset}:  #{cpu}"
    puts "#{colors[options.color]}  \\___/  #{reset}#{bold}#{label[4]}#{reset}:  #{mem_usage} MiB / #{mem} MiB"
    puts ""
  end
end

Main.run

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

  def self.parse : Options
    options = Options.new

    OptionParser.parse do |parser|
      parser.on "-l", "--lowercase", "Use lowercase labels" do
        options.lowercase = true
      end

      parser.on "-c COLOR", "--color COLOR", "Pick a color output (0-7)" do |c|
        color = c.to_i
        if color < 0 || color > 7
          puts "Invalid color. Please choose a value between 0 and 7."
          exit
        end
        options.color = color
      end

      parser.on "-h", "--help", "Show help" do
        puts parser
        exit
      end
    end

    options
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

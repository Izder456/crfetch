require "process"
require "option_parser"

module Manip
  # Use a constant here
  MEBIBYTE = 1048576

  def self.bytesToMebibytes(bytes : String) : String
    # Implement turning bytes into Mebibytes
    bytes = bytes.strip.to_f / MEBIBYTE

    "%.2f" % bytes
  end
end

module Resource
  def self.runSysCommand(command : String) : String
    channel = Channel(String).new
    spawn do
      output = IO::Memory.new
      Process.run(command, shell: true, output: output)
      output.close
      channel.send(output.to_s)
    end
    channel.receive.strip
  end

  def self.getPlatform : String
    case runSysCommand("uname")
    when /Linux/
      "Linux #{runSysCommand("grep PRETTY_NAME /etc/os-release | cut -d = -f 2")}"
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

  def self.getRelease : String
    runSysCommand("uname -r")
  end

  def self.getUser : String
    runSysCommand("whoami")
  end

  def self.getHost : String
    runSysCommand("hostname")
  end

  def self.getMemory : String
    case getPlatform
    when /Linux/
      memory = runSysCommand("free -b | awk '/Mem/ {print $2}'")
    when /BSD/
      memory = runSysCommand("sysctl -n hw.physmem")
    else
      memory = "0"
    end
    Manip.bytesToMebibytes(memory)
  end

  def self.getMemoryUsage : String
    case getPlatform
    when /Linux/
      used_memory = runSysCommand("free -b | awk '/Mem/ {print $3}'")
    when /BSD/
      used_memory = runSysCommand("vmstat -s | awk '/pages active/ {printf \"%.2f\\n\", $1*4096}'")
    else
      used_memory = "0"
    end
    Manip.bytesToMebibytes(used_memory)
  end

  def self.getCpu : String
    case getPlatform
    when /Linux/
      runSysCommand("lscpu | grep 'Model name'| cut -d : -f 2 | awk '{$1=$1}1'")
    when /BSD/
      runSysCommand("sysctl -n hw.model")
    else
      "Could not get CPU"
    end
  end
end

module OptionHandler
  class Options
    property lowercase : Bool = false # Default UPCASE
    property color : Int32 = 4 # Default Blue
    property ascii : String = "Tear" # Default ASCII
  end

  # Inherit Exception class
  class OptionError < Exception end

  def self.parse : Options
    options = Options.new

    OptionParser.parse do |parser|
      parser.on("-l", "--lowercase", "Use lowercase labels") { options.lowercase = true }
      parser.on("-c COLOR", "--color COLOR", "Pick a color output") do |c|
        color = c.to_i?
        raise OptionError.new("Invalid color. Please choose a value between 0 and 7.") if color.nil? || color < 0 || color > 7
        options.color = color
      end
      parser.on("-a ASCII", "--ascii ASCII", "Choose ASCII art") do |a|
        raise OptionError.new("Invalid ASCII art option. Choose from: None, Tear, Linux, OpenBSD, NetBSD, FreeBSD") unless ["None", "Tear", "Linux", "OpenBSD", "NetBSD", "FreeBSD"].includes?(a)
        options.ascii = a
      end
      parser.on("-h", "--help", "Show help") { puts help_message; exit }
    end

    options
  rescue error : OptionError | OptionParser::InvalidOption | OptionParser::MissingOption
    STDERR.puts "Error: #{error.message}"
    exit(1)
  end

  def self.help_message : String
    colors = (30..37).map { |c| "\e[#{c}m#{c - 30}\e[0m" }.join(" ")
    <<-HELP
    Usage: crfetch [options]
    -l, --lowercase         Use lowercase labels
    -c, --color COLOR       Pick a color output [default = 4]
                            (#{colors})
    -a, --ascii ASCII       Choose ASCII art [default = Tear]
                            (None, Tear, Linux, OpenBSD, NetBSD, FreeBSD)
    -h, --help              Show help
    HELP
  end
end

module Main
  def self.run
    options = OptionHandler.parse

    # get resources
    user = Resource.getUser
    host = Resource.getHost
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
    colors = (30..37).map { |c| "\e[#{c}m" }

    # labels
    label = ["USER", "OS", "VER", "CPU", "MEM"]
    ## set lowercase if lowercase
    label = label.map(&.downcase) if options.lowercase

    # ASCII art
    ascii_art = {
      "None" => Array.new(6, "  "),
      "Tear" => [
        "         ",
        "    ,    ",
        "   / \\   ",
        "  /   \\  ",
        " |     | ",
        "  \\___/  ",
      ],
      "Linux" => [
        "     ___     ",
        "    [..,|    ",
        "    [<> |    ",
        "   / __` \\   ",
        "  ( /  \\ {|  ",
        "  /\\ __)/,)  ",
        " (}\\____\\/   "
      ],
      "OpenBSD" => [
        "      _____      ",
        "    \\-     -/    ",
        " \\_/ .`  ,   \\   ",
        " | ,    , 0 0 |  ",
        " |_  <   }  3 }  ",
        " / \\`   . `  /   ",
        "    /-_____-\\    "
      ],
      "NetBSD" => [
        "                       ",
        " \\\\\\\`-______,----__    ",
        "  \\\\  -  _  __,---\\`_  ",
        "   \\\\  ,  . \\`.____    ",
        "    \\\\-______,----\\`-  ",
        "     \\\\                ",
        "      \\\\               ",
        "       \\\\              "
      ],
      "FreeBSD" => [
        "                ",
        " /\\.-^^^^^-./\\  ",
        " \\_)  ,.,  (_/  ",
        " |     W     |  ",
        " |     |     |  ",
        "  ;    |    ;   ",
        "   '-_____-'    "
      ]
    }

    # get chosen ascii art
    chosen_ascii = ascii_art[options.ascii]

    # get the maximum width of the labels
    max_label_width = label.map(&.size).max

    # output
    max_lines = [chosen_ascii.size, 5].max
    (0...max_lines).map do |index|
      ascii_line = chosen_ascii.fetch(index, " " * chosen_ascii[0].size)
      info_line = {
        1 => "#{bold}#{colors[options.color]}%-#{max_label_width}s#{reset} -> %s" % [label[0], "#{user}@#{host}"],
        2 => "#{bold}#{colors[options.color]}%-#{max_label_width}s#{reset} -> %s" % [label[1], os],
        3 => "#{bold}#{colors[options.color]}%-#{max_label_width}s#{reset} -> %s" % [label[2], release],
        4 => "#{bold}#{colors[options.color]}%-#{max_label_width}s#{reset} -> %s" % [label[3], cpu],
        5 => "#{bold}#{colors[options.color]}%-#{max_label_width}s#{reset} -> %s" % [label[4], "#{mem_usage} MiB / #{mem} MiB"]
      }.fetch(index, "")

      "#{colors[options.color]}#{ascii_line}#{reset}#{info_line}"
    end.each { |line| puts line }

    puts "" # Add newline padding at the bottom
  end
end

Main.run

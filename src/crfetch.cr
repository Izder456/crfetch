require "option_parser"

module Manip
  # Use a constant here
  MEBIBYTE = 1048576

  def self.bytes_to_mebibytes(bytes : String) : String
    bytes = bytes.strip.to_f / MEBIBYTE

    # return with two decimal places
    "%.2f" % bytes
  end
end

module Resource
  private def self.scrape_file(query : String, file : String) : String
    File.each_line(file) do |line|
      if line.includes?(query)
        return line.split('=', 2)[1].delete('"').strip
      end
    end
    ""
  end

  private def self.uname(argument : String) : String
    `uname #{argument}`.strip
  end

  def self.get_platform : String
    release_file = "/etc/os-release"
    uname = self.uname("")
    if File.file?(release_file)
      name = self.scrape_file("PRETTY_NAME", release_file).strip
    else
      name = ""
    end

    "#{uname} #{name}"
  end

  def self.get_release : String
    release_file = "/etc/os-release"

    case get_platform
    when /BSD/
      kernel_version = `sysctl -n kern.osrelease`.strip
    else
      kernel_version = self.uname("-r").strip
    end

    if File.file?(release_file)
      distro_version = self.scrape_file("VERSION_ID", release_file).strip
      "#{kernel_version} #{distro_version}"
    else
      kernel_version.strip
    end
  end

  def self.get_user : String
    env = ENV["USER"]
    user = env || "Could not get $USER"
    user.to_s
  end

  def self.get_host : String
    System.hostname
  end

  def self.get_shell : String
    path = ENV["SHELL"]
    shell = File.basename(path) if path || "Could not get $SHELL"
    shell.to_s
  end

  def self.get_memory : String
    case get_platform
    when /Linux/
      memory = `free -b | awk '/Mem/ {print $2}'`
    when /BSD/
      memory = `sysctl -n hw.physmem`
    else
      memory = "0"
    end
    Manip.bytes_to_mebibytes(memory.to_s)
  end

  def self.get_memory_usage : String
    case get_platform
    when /Linux/
      used_memory = `free -b | awk '/Mem/ {print $3}'`
    when /BSD/
      used_memory = `vmstat -s | awk '/pages active/ {printf "%.2f\\n", $1*4096}'`
    else
      used_memory = "0"
    end
    Manip.bytes_to_mebibytes(used_memory)
  end

  def self.get_cpu : String
    case get_platform
    when /Linux/
      `lscpu | grep 'Model name'| cut -d : -f 2 | awk '{$1=$1}1'`
    when /BSD/
      `sysctl -n hw.model`
    else
      "Could not get CPU"
    end
  end
end

module OptionHandler
  class Options
    property lowercase = false
    property color = 4
    property ascii = "Tear"
    property separator = " -> "
  end

  # inherit the Exception class
  class OptionError < Exception; end

  def self.parse
    options = Options.new

    OptionParser.parse do |parser|
      parser.on("-l", "--lowercase", "Use lowercase labels") { options.lowercase = true }
      parser.on("-s STRING", "--separator STRING", "Separator") { |s| options.separator = s || raise OptionError.new("Invalid Separator") }
      parser.on("-c COLOR", "--color COLOR", "Pick a color output") do |c|
        color = c.to_i?
        raise OptionError.new("Invalid color (0-7)") unless color && (0..7).includes?(color)
        options.color = color
      end
      parser.on("-a ASCII", "--ascii ASCII", "Choose ASCII art") do |a|
        valid_ascii = ["None", "Tear", "Linux", "OpenBSD", "NetBSD", "FreeBSD", "FreeBSDTrident", "GhostBSD", "GhostBSDGhost"]
        raise OptionError.new("Invalid ASCII art option") unless valid_ascii.includes?(a)
        options.ascii = a
      end
      parser.on("-h", "--help", "Show help") { puts help_message; exit }
    end

    options
  rescue error : OptionError | OptionParser::InvalidOption | OptionParser::MissingOption
    STDERR.puts "Error: #{error.message}"
    exit(1)
  end

  def self.help_message
    colors = (30..37).map { |c| "\e[#{c}m#{c - 30}\e[0m" }.join(" ")
    <<-HELP
    Usage: crfetch [options]
    -l, --lowercase         Use lowercase labels
    -s, --separator STRING  Separator [default = " -> "]
    -c, --color COLOR       Pick a color output [default = 4]
                            (#{colors})
    -a, --ascii ASCII       Choose ASCII art [default = Tear]
                            (None, Tear, Linux, OpenBSD, NetBSD, FreeBSD, FreeBSDTrident, GhostBSD, GhostBSDGhost)
    -h, --help              Show help
    HELP
  end
end

module Main

  
  ASCII_ART = {
    "None" => Array.new(7, "  "),
    "Tear" => [
      "         ",
      "    ,    ",
      "   / \\   ",
      "  /   \\  ",
      " |     | ",
      "  \\___/  ",
      "         ",
    ],
    "Linux" => [
      "     ___     ",
      "    [..,|    ",
      "    [<> |    ",
      "   / __` \\   ",
      "  ( /  \\ {|  ",
      "  /\\ __)/,)  ",
      " (}\\____\\/   ",
      "             ",
    ],
    "OpenBSD" => [
      "      _____      ",
      "    \\-     -/    ",
      " \\_/ .`  ,   \\   ",
      " | ,    , 0 0 |  ",
      " |_  <   }  3 }  ",
      " / \\`   . `  /   ",
      "    /-_____-\\    ",
      "                 ",
    ],
    "NetBSD" => [
      "                       ",
      " \\\\\\`-______,----__    ",
      "  \\\\  -  _  __,---\\`_  ",
      "   \\\\  ,  . \\`.____    ",
      "    \\\\-______,----\\`-  ",
      "     \\\\                ",
      "      \\\\               ",
      "       \\\\              ",
      "                       ",
    ],
    "FreeBSD" => [
      "                ",
      " /\\.-^^^^^-./\\  ",
      " \\_)       (_/  ",
      " |           |  ",
      " |           |  ",
      "  ;         ;   ",
      "   '-_____-'    ",
      "                ",
    ],
    "FreeBSDTrident" => [
      "                ",
      " /\\.-^^^^^-./\\  ",
      " \\_)  ,.,  (_/  ",
      " |     W     |  ",
      " |     |     |  ",
      "  ;    |    ;   ",
      "   '-_____-'    ",
      "                ",
    ],
    "GhostBSD" => [
      "            ",
      "    _____   ",
      "   / __  )  ",
      "  ( /_/ /   ",
      "  _\\_, /    ",
      " \\____/     ",
      "            ",
      "            ",
    ],
    "GhostBSDGhost" => [
      "   _______   ",
      "  /       \\  ",
      "  | () () |  ",
      "  |       |  ",
      "  |   3   |  ",
      "  /       \\  ",
      "  ^^^^^^^^^  ",
      "              ",
    ],
  }

  COLORS = (30..37).map { |c| "\e[#{c}m" }

  BOLD = "\e[1m"
  RESET = "\e[0m"
  
  def self.run
    options = OptionHandler.parse

    # define resources and their corresponding methods
    resources = {
      "user"      => -> { Resource.get_user },
      "host"      => -> { Resource.get_host },
      "shell"     => -> { Resource.get_shell },
      "os"        => -> { Resource.get_platform },
      "release"   => -> { Resource.get_release },
      "cpu"       => -> { Resource.get_cpu },
      "mem_usage" => -> { Resource.get_memory_usage },
      "mem"       => -> { Resource.get_memory },
    }

    # create channel to act on
    channel = Channel(Tuple(String, String)).new

    # spawn fibers to concurrently fetch
    resources.each do |key, method|
      spawn { channel.send({key, method.call}) }
    end

    # ensure all fibers are finished
    Fiber.yield

    # collect results from the channel
    results = {} of String => String
    resources.size.times do
      key, value = channel.receive
      results[key] = value
    end

    # labels
    label = ["USER", "OS", "SHELL", "VER", "CPU", "MEM"]
    # set lowercase if lowercase
    label = label.map(&.downcase) if options.lowercase

    # get chosen ascii art
    chosen_ascii = ASCII_ART[options.ascii]

    # get the maximum width of the labels
    max_label_width = label.map(&.size).max

    # output
    max_lines = [chosen_ascii.size, 6].max
    (0...max_lines).map do |index|
      ascii_line = chosen_ascii.fetch(index, " " * chosen_ascii[0].size)
      info_line = {
        1 => "#{BOLD}#{COLORS[options.color]}%-#{max_label_width}s#{RESET}#{options.separator}%s" % [label[0], "#{results["user"]}@#{results["host"]}"],
        2 => "#{BOLD}#{COLORS[options.color]}%-#{max_label_width}s#{RESET}#{options.separator}%s" % [label[1], results["os"]],
        3 => "#{BOLD}#{COLORS[options.color]}%-#{max_label_width}s#{RESET}#{options.separator}%s" % [label[2], results["shell"]],
        4 => "#{BOLD}#{COLORS[options.color]}%-#{max_label_width}s#{RESET}#{options.separator}%s" % [label[3], results["release"]],
        5 => "#{BOLD}#{COLORS[options.color]}%-#{max_label_width}s#{RESET}#{options.separator}%s" % [label[4], results["cpu"]],
        6 => "#{BOLD}#{COLORS[options.color]}%-#{max_label_width}s#{RESET}#{options.separator}%s" % [label[5], "#{results["mem_usage"]} MiB / #{results["mem"]} MiB"],
      }.fetch(index, "")

      "#{COLORS[options.color]}#{ascii_line}#{RESET}#{info_line}"
    end.each { |line| puts line }

    puts "" # Add newline padding at the bottom
  end
end

Main.run

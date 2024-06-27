require "process"

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
    # Implement running system command and yoinking output
    output = IO::Memory.new
    Process.run(command, shell: true, output: output)
    output.close

    output.to_s
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
    self.runSysCommand("uname -r")
  end

  def self.getUser : String?
    # Implement Getting Username
    self.runSysCommand("whoami")
  end

  def self.getMemory : String?
    # Implement Getting Memory Usage
    os = getPlatform
    case os
    when /Linux/
      memory = self.runSysCommand("free -b | awk '/Mem/ {print $2}'")
    when /BSD/
      memory = self.runSysCommand("sysctl -n hw.physmem")
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
      used_memory = runSysCommand("free -b | awk '/Mem/ {print $3}'")
    when /BSD/
      used_memory = runSysCommand("vmstat -s | awk '/pages active/ {printf \"%.2f\\n\", $1*4096}'")
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
      cpu_info = File.read("/proc/cpuinfo")
      match = cpu_info.match(/model\ name\s+:\s+(.+)/)

      match[1] if match
    when "macOS"
      cpu_info = runSysCommand("sysctl -n machdep.cpu.brand_string").strip

      cpu_info unless cpu_info.empty?
    when /BSD/
      cpu_info = runSysCommand("sysctl -n hw.model").strip

      cpu_info unless cpu_info.empty?
    else
      nil
    end
  end
end

def fetch
  user = Resource.getUser
  os = Resource.getPlatform
  release = Resource.getRelease
  cpu = Resource.getCpu
  mem_usage = Resource.getMemoryUsage
  mem = Resource.getMemory

  blue = "\e[34m"
  bold = "\e[1m"
  reset = "\e[0m"

  puts "#{blue}    ,    #{reset}#{bold}USER#{reset}: #{user}"
  puts "#{blue}   / \\   #{reset}#{bold}OS#{reset}:   #{os}"
  puts "#{blue}  /   \\  #{reset}#{bold}VER#{reset}:  #{release}"
  puts "#{blue} |     | #{reset}#{bold}CPU#{reset}:  #{cpu}"
  puts "#{blue}  \\___/  #{reset}#{bold}MEM#{reset}:  #{mem_usage} MiB/#{mem} MiB"
end

fetch

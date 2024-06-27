require "process"

module Crfetch
  VERSION = "0.1.0"

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
      distro_info = File.read("/etc/os-release")
      match = distro_info.match(/PRETTY_NAME\s+=\s+(.+)/)
      "Linux #{match}"
    when /Darwin/
      "macOS"
    when /FreeBSD/
      "FreeBSD"
    when /OpenBSD/
      "OpenBSD"
    when /NetBSD/
      "NetBSD"
    else
      "I dunno"
    end
  end

  def self.getMemory : String?
    # Implement Getting Memory Usage
    os = getPlatform
    case os
    when /Linux/
      memory = self.runSysCommand("vmstat -s | grep 'total memory' | awk '{print $1}' | awk '{printf \"%.2f\\n\", $1*1024}'")
    when "macOS"
      memory = self.runSysCommand("sysctl -n hw.memsize")
    when /BSD/
      memory = self.runSysCommand("sysctl -n hw.physmem")
    else
      memory = ""
    end

    megabyte = 1048576
    memory = memory.strip.to_f / megabyte
    output = "%.2f" % memory
  end

  def self.getMemoryUsage : String?
    # Implement getting memory usage
    os = getPlatform
    case os
    when /Linux/
      command = "vmstat -s | grep 'used memory' | awk '{print $1}' | awk '{printf \"%.2f\\n\", $1/1024}'"
      self.runSysCommand(command).strip
    when "macOS"
      command = "vm_stat | grep 'Pages active' | awk '{print $3}' | sed 's/\.$//' | awk '{printf \"%.2f\\n\", $1*4096/1024/1024}'"
      runSysCommand(command).strip
    when /BSD/
      command = "vmstat -s | grep 'pages active' | awk '{print $1}' | awk '{printf \"%.2f\\n\", $1*4096/1024/1024}'"
      runSysCommand(command).strip
    else
      nil
    end
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

os = Crfetch.getPlatform
mem_usage = Crfetch.getMemoryUsage
mem = Crfetch.getMemory
cpu = Crfetch.getCpu

puts "OS:  #{os}"
puts "MEM: #{mem_usage}/#{mem}MB"
puts "CPU: #{cpu}"

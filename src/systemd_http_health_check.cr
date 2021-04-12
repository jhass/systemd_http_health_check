require "socket"
require "http/client"

@[Link(pkg_config: "libsystemd")]
lib LibSystemd
  fun sd_notify(unset_env : LibC::Int, message : LibC::Char*)
end

def usage
  abort "Usage: #{PROGRAM_NAME} <endpoint> [interval]"
end

def warn(message)
  STDERR.puts message
end

def sd_notify(message : String)
  LibSystemd.sd_notify(0, message.to_unsafe)
end

def up?
  response = HTTP::Client.get ENDPOINT
  response.success?
rescue e
  warn "Failed to poll HTTP endpoint at '#{ENDPOINT}': #{e.message}"
  false
end

def notify_ready
  until up?
    sleep 1
  end

  sd_notify "READY=1"
end

def watchdog
  sd_notify "WATCHDOG_USEC=#{(INTERVAL + 5.seconds).total_microseconds.to_i}"

  while up?
    sd_notify "WATCHDOG=1"
    sleep INTERVAL
  end

  warn "Assuming service is down, sending trigger."
  sd_notify "WATCHDOG=trigger"
end

usage unless 0 < ARGV.size <= 2
usage unless ARGV.size == 1 || !ARGV[1].to_i?.nil?
abort "NOTIFY_SOCKET is empty, running with Type=notify under systemd?" unless ENV.has_key?("NOTIFY_SOCKET")

ENDPOINT = ARGV[0]
INTERVAL = (ARGV[1]? || 60).to_i.seconds

notify_ready
watchdog

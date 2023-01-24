require "socket"
require "http/client"

@[Link("systemd", pkg_config: "libsystemd")]
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
  SUCCESS_CODES.includes? response.status_code
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

def parse_success_codes(codes)
  codes.split(",").flat_map {|code_or_range| parse_success_code(code_or_range) }
rescue e
  warn "Couldn'T parse HTTP_SUCCESS_CODES: #{e.message}, using default of 200-299"
  [*200..299]
end

def parse_success_code(code_or_range)
  return code_or_range.to_i unless code_or_range.includes? '-'
  start_code, end_code = code_or_range.split('-')
  [*start_code.to_i..end_code.to_i]
end

usage unless 0 < ARGV.size <= 2
usage unless ARGV.size == 1 || !ARGV[1].to_i?.nil?
abort "NOTIFY_SOCKET is empty, running with Type=notify under systemd?" unless ENV.has_key?("NOTIFY_SOCKET")

ENDPOINT = ARGV[0]
INTERVAL = (ARGV[1]? || 60).to_i.seconds
SUCCESS_CODES = parse_success_codes ENV.fetch("HTTP_SUCCESS_CODES", "200-299")

notify_ready
watchdog

# systemd\_http\_health\_check

This is a little companion daemon that notifies systemd about the availability of an HTTP server via the `sd_notify` API. The intended usecase is to let systemd restart a service when it has gone bad.

## Install

1. Install [Crystal](https://crystal-lang.org/) and libsystemd.
2. Clone this repository
3. Run `shards build --release`.
4. Copy `bin/systemd_http_health_check` wherevever you please.

## Usage

The daemon expects to be started along side the service it is supposed to watch and have access to its `NOTIFY_SOCKET`.
It takes two parameters, first the HTTP URL to watch and optionally second an interval in seconds. The default interval if none is given is 60 seconds. The daemon will notify systemd about the watchdog interval plus 5 seconds leeway, so there's no need to set it explicilty in the service file. After startup the service will wait for the given HTTP URL to respond with a code in the 2xx range. Once it sees this for the first time it notifies systemd about the service being ready. From then on it will keep polling the HTTP URL every interval seconds, resetting systemd's watchdog for a response in the 2xx range. If there's no successfull response it will trigger the watchdog.

In case you want to change which response codes are considered a successful response, you can set the `HTTP_SUCCESS_CODES` environment variable to a comma separated list. Each item can either be a valid HTTP status code or an inclusive range separated by a dash (`-`). For example setting `HTTP_SUCCESS_CODES` to `200-203,301` would consider the codes 200, 201, 202, 203 and 301 as a successful response.

Unforutunately systemd offers no good way to run a companion daemon with access to the notify socket alongside a service. To avoid the complexity of forking off a child process in the watchdog daemon the recommend setup is using a shell to start both processes:

```service
[Unit]
# ...

[Service]
# ...
Type=notify
NotifyAccess=all
Restart=always
# The single ampersand here is no typo but to send the health check dameon into the background
ExecStart=/bin/sh -c '/usr/local/bin/systemd_http_health_check "http://localhost:3000/health-check & exec /usr/local/bin/your-http-service -p 3000"
```

## Contributing

Contributions are always welcome, just send a pull request.

# Relay Protocol

Qu Controller can expose its mixer state and controls to LAN clients over a
plain TCP connection. Enable the relay in Settings, then connect to the Mac's
LAN address and the configured port. The default port is `51326`.
The relay listens on all network interfaces.

The protocol uses UTF-8 JSON Lines: each message is one JSON object followed by
a newline (`\n`). Authentication, encryption, and service discovery are not
part of the initial protocol.

## Server Messages

The server sends a complete snapshot as soon as a client connects and whenever
the mixer connection or channel state changes:

```json
{"type":"snapshot","connection":{"phase":"connected","message":"Connected","endpoint":{"host":"192.168.1.50","port":51325}},"channels":[{"id":"ch1","level":0.65,"isMuted":false,"hasSignal":true,"name":"Vocals"}]}
```

Connection phases are `disconnected`, `connecting`, `connected`, and `error`.
Channel levels range from `0` to `1`.

Invalid client messages receive an error while the connection remains open:

```json
{"type":"error","message":"setLevel requires channel and level between 0 and 1"}
```

## Client Commands

Set a channel level:

```json
{"type":"setLevel","channel":"ch1","level":0.65}
```

Set a channel mute state:

```json
{"type":"setMute","channel":"ch1","isMuted":true}
```

Shut down the connected mixer:

```json
{"type":"shutdownMixer"}
```

The relay executes shutdown immediately. Clients should require confirmation
before sending this command because the relay does not provide its own prompt.

Valid channel identifiers are `ch1` through `ch16` and `mainLr`. Successful
commands are reflected in a subsequent snapshot broadcast to every connected
client.

## Command-Line Example

If the Mac is at `192.168.1.20` and uses the default relay port:

```bash
nc 192.168.1.20 51326
```

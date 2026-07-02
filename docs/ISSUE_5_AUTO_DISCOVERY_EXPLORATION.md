# Issue 5: Qu Mixer Auto-Discovery Exploration

## Summary

Automatic discovery looks technically possible for this app, but only as a
prototype-first feature.

The current app connects directly to a user-supplied host on TCP port `51325`
and then speaks the Qu MIDI protocol. The Qu MIDI protocol reference used by
this repo starts after the IP address is already known, so it does not by
itself provide a mixer discovery mechanism. That means discovery has to come
from the local network layer, not from the existing MIDI transport.

## Current App Constraints

- The app currently requires manual host entry in the main window.
- The network controller connects to `MixerEndpoint(host: ..., port: 51325)`.
- There is no existing Bonjour, mDNS, UDP broadcast, or subnet scan code in the
  project today.

Relevant code:

- `Qu Controller/MixerScreenViewModel.swift`
- `Qu Controller/QuNetworkMixerController.swift`

## Viable Discovery Approaches

### 1. Bonjour / mDNS browse

This is the cleanest option if the mixer advertises a stable Bonjour service.

Why it is attractive:

- It is passive.
- It avoids broad subnet probing.
- Apple provides first-party APIs for it via `NWBrowser` and `NSNetServiceBrowser`.

Important platform constraint:

- Apple’s SDK headers state that `NSBonjourServices` and
  `NSLocalNetworkUsageDescription` are required in `Info.plist` for local
  network access through Bonjour APIs.

Current risk:

- We do not yet have evidence in this repo that Qu mixers advertise a Bonjour
  service type that can be browsed reliably.
- The Qu MIDI protocol document does not define a Bonjour service type or
  discovery handshake.

Recommendation:

- Treat Bonjour as the first thing to test on real hardware, not as an
  assumption.

### 2. User-initiated TCP probe on likely local addresses

If Bonjour is unavailable, the app could probe for a mixer by attempting short,
bounded TCP connections to port `51325` on the local subnet.

Why it is feasible:

- The app already knows how to validate a working Qu connection once a host is
  reached.
- A successful connection followed by the existing system-state request is a
  strong signal that the target is a Qu mixer.

Risks:

- Slower than Bonjour.
- Can create noticeable delay on large or unusual subnets.
- Can produce false positives if some other device happens to answer on the
  same port.
- More likely to look like scanning behavior to users or corporate networks.

Recommendation:

- Only consider this as an explicit user action such as `Find Mixer`, not as
  silent background behavior.
- Keep it tightly scoped: current subnet only, short timeouts, stop on first
  valid Qu handshake.

### 3. UDP broadcast or proprietary discovery

This would be attractive if Allen & Heath exposed a documented discovery
protocol, but we do not currently have evidence for one in the references used
by this repo.

Recommendation:

- Do not plan around this unless a vendor document or packet capture confirms
  it exists.

## macOS Permissions and UX Constraints

- Bonjour-based discovery requires `NSBonjourServices` and
  `NSLocalNetworkUsageDescription` in `Info.plist`.
- Any local-network discovery feature should be user-initiated and clearly
  explained in the UI.
- If the app is sandboxed or distributed with tighter entitlements later, local
  network behavior should be retested at that point.

## Reliability and Risk Assessment

### Reliability

- Bonjour would likely be reliable if the mixer actually advertises a stable
  service type.
- TCP probing can work, but reliability depends on subnet shape, firewall
  rules, Wi-Fi isolation, VPN interference, and whether the Mac and mixer are
  truly on the same broadcast domain.

### False positives

- Bonjour has a lower false-positive risk because service types are explicit.
- TCP probing has higher false-positive risk and needs validation through the
  existing Qu handshake before presenting a result to the user.

### User experience tradeoffs

- Best case: `Find Mixer` returns a result quickly and fills in the host field.
- Worst case: no result is found, or multiple candidate devices are returned.
- The feature should therefore support:
  - no-result messaging
  - multiple-result selection
  - manual host entry as the fallback path

## Recommended Next Step

Recommended next step: prototype, not full implementation.

Prototype order:

1. Test whether a real Qu mixer advertises a Bonjour service visible to
   `NWBrowser` / `NSNetServiceBrowser`.
2. If yes, implement a small Bonjour discovery prototype.
3. If no, decide whether an explicit `Find Mixer` subnet probe is acceptable
   for this app’s expected environments.
4. If probing feels too noisy or unreliable, defer the feature and keep manual
   host entry.

## Suggested Implementation Shape If Prototyping Proceeds

- Add a `Find Mixer` action beside the host field.
- Try Bonjour first.
- If Bonjour finds one validated mixer, fill the host automatically.
- If Bonjour finds many, let the user choose.
- If Bonjour finds none, optionally offer a bounded subnet probe.
- Reuse the existing Qu connection handshake before treating any host as valid.

## Bottom Line

Auto-discovery is feasible enough to justify a prototype.

The safest path is:

- prefer Bonjour if a real mixer advertises a browseable service
- fall back to an explicit, bounded port `51325` probe only if needed
- avoid silent background scanning
- keep manual host entry as a permanent fallback

## Sources

- Allen & Heath Qu MIDI Protocol V1.9:
  `https://www.allen-heath.com/content/uploads/2023/06/Qu_MIDI_Protocol_V1.9.pdf`
- Apple SDK header:
  `Foundation.framework/Headers/NSNetServices.h`
- Apple SDK header:
  `Network.framework/Headers/browse_descriptor.h`

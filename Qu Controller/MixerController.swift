//
//  MixerController.swift
//  Qu Controller
//

import Combine

@MainActor
protocol MixerController: AnyObject {
    var transportKind: MixerTransportKind { get }
    var channels: [MixerChannelState] { get }
    var connectionState: MixerConnectionState { get }
    var connectionOptions: [MixerConnectionOption] { get }
    var channelsPublisher: AnyPublisher<[MixerChannelState], Never> { get }
    var connectionStatePublisher: AnyPublisher<MixerConnectionState, Never> { get }
    var connectionOptionsPublisher: AnyPublisher<[MixerConnectionOption], Never> { get }

    func connect(to target: MixerConnectionTarget) async
    func disconnect()
    func shutdownMixer() async
    func setLevel(for channelID: MixerChannelID, level: FaderLevel)
    func setMute(for channelID: MixerChannelID, isMuted: Bool)
    func setSignalMonitoringEnabled(_ isEnabled: Bool)
    func refreshConnectionOptions()
}

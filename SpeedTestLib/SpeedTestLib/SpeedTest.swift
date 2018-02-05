//
//  SpeedTest.swift
//  SpeedTestLib
//
//  Created by dhaurylenka on 2/5/18.
//  Copyright © 2018 Exadel. All rights reserved.
//

import Foundation

enum SpeedTestError: Error {
    case networkError
    case hostNotFound
}

final class SpeedTest {
    private let hostService: HostsProviderService
    private let pingService: HostPingService
    
    required init(hosts: HostsProviderService, ping: HostPingService) {
        self.hostService = hosts
        self.pingService = ping
    }
    
    convenience init() {
        self.init(hosts: SpeedTestService(), ping: DefaultHostPingService())
    }
    
    func findBestHost(from max: Int, timeout: TimeInterval, closure: @escaping (Result<URL, SpeedTestError>) -> ()) {
        hostService.getHosts(max: max, timeout: timeout) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .error(_):
                DispatchQueue.main.async {
                    closure(.error(.networkError))
                }
            case .value(let hosts):
                strongSelf.pingAllHosts(hosts: hosts, timeout: timeout) { pings in
                    DispatchQueue.main.async {
                        closure(strongSelf.findBestPings(from: pings))
                    }
                }
            }
        }
    }
    
    private func pingAllHosts(hosts: [URL], timeout: TimeInterval, closure: @escaping ([(host: URL, ping: Int)]) -> ()) {
        let group = DispatchGroup()
        var pings = [(URL, Int)]()
        hosts.forEach { url in
            group.enter()
            pingService.ping(url: url, timeout: timeout, closure: { result in
                switch result {
                case .error(_): break
                case .value(let ping):
                    pings.append((url, ping))
                }
                group.leave()
            })
        }
        group.notify(queue: DispatchQueue.global(qos: .default)) {
            closure(pings)
        }
    }
    
    private func findBestPings(from pings: [(host: URL, ping: Int)]) -> Result<URL, SpeedTestError> {
        let best = pings.min(by: { (left, right) in
            left.ping < right.ping
        })
        if let best = best {
            return .value(best.host)
        } else {
            return .error(.hostNotFound)
        }
    }
}
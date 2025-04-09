// OSCManager.swift
// Vibe ID
//
// Created by Studio Carlos in 2025.
// Copyright (C) 2025 Studio Carlos
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import OSCKit
import Darwin
import Combine

@MainActor
class OSCManager {

    // Shared instance for LLM prompts
    private let llmManager = LLMManager.shared
    
    // Store cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // Current state
    private(set) var isConnected = true
    private let oscClient = OSCKit.OSCClient()
    
    // Enable detailed logging
    private var verboseLogging: Bool = true

    init() {
        // OSCManager initialized
    }

    // MARK: - OSC Message Operations
    
    /// Sends a manual prompt with custom parameters
    func sendManualPrompt(prompt: String, host: String, port: Int) {
        let oscAddress = "/vibeid/manual"
        let customMessage = OSCKit.OSCMessage(OSCKit.OSCAddressPattern(oscAddress), values: [prompt])
        send(customMessage, to: host, port: port)
    }

    /// Sends a single OSC message in a simple and direct way.
    func send(_ message: OSCKit.OSCMessage, to host: String, port: Int) {
        guard !host.isEmpty, port > 0, port <= 65535 else {
            return
        }
        
        // Direct synchronous approach
        do {
            try oscClient.send(message, to: host, port: UInt16(port))
        } catch {
            // Try a second time after a short delay
            do {
                Thread.sleep(forTimeInterval: 0.05)
                try oscClient.send(message, to: host, port: UInt16(port))
            } catch {
                // Failed both attempts
            }
        }
    }

    /// Tests the OSC connection by sending a simple message.
    func testConnection(to host: String, port: Int) -> Bool {
        guard !host.isEmpty, port > 0, port <= 65535 else {
            return false
        }
        
        // Create a simple test message
        let testMsg = OSCKit.OSCMessage(OSCKit.OSCAddressPattern("/vibeid/test"), values: ["ping"])
        
        do {
            try oscClient.send(testMsg, to: host, port: UInt16(port))
            return true
        } catch {
            return false
        }
    }

    /// Sends identified track information via OSC.
    func sendTrackInfo(track: TrackInfo, host: String, port: Int) {
        // Send basic track information
        let titleMsg = OSCKit.OSCMessage(OSCKit.OSCAddressPattern("/vibeid/track/title"), values: [track.title ?? ""])
        send(titleMsg, to: host, port: port)
        
        let artistMsg = OSCKit.OSCMessage(OSCKit.OSCAddressPattern("/vibeid/track/artist"), values: [track.artist ?? ""])
        send(artistMsg, to: host, port: port)
        
        let genreMsg = OSCKit.OSCMessage(OSCKit.OSCAddressPattern("/vibeid/track/genre"), values: [track.genre ?? ""])
        send(genreMsg, to: host, port: port)
        
        let artworkMsg = OSCKit.OSCMessage(OSCKit.OSCAddressPattern("/vibeid/track/artwork"), values: [track.artworkURL?.absoluteString ?? ""])
        send(artworkMsg, to: host, port: port)
        
        // Send prompts
        if let prompt1 = track.prompt1 {
            let prompt1Msg = OSCKit.OSCMessage(OSCKit.OSCAddressPattern("/vibeid/track/prompt1"), values: [prompt1])
            send(prompt1Msg, to: host, port: port)
        }
        if let prompt2 = track.prompt2 {
            let prompt2Msg = OSCKit.OSCMessage(OSCKit.OSCAddressPattern("/vibeid/track/prompt2"), values: [prompt2])
            send(prompt2Msg, to: host, port: port)
        }
        if let prompt3 = track.prompt3 {
            let prompt3Msg = OSCKit.OSCMessage(OSCKit.OSCAddressPattern("/vibeid/track/prompt3"), values: [prompt3])
            send(prompt3Msg, to: host, port: port)
        }
        if let prompt4 = track.prompt4 {
            let prompt4Msg = OSCKit.OSCMessage(OSCKit.OSCAddressPattern("/vibeid/track/prompt4"), values: [prompt4])
            send(prompt4Msg, to: host, port: port)
        }
        if let prompt5 = track.prompt5 {
            let prompt5Msg = OSCKit.OSCMessage(OSCKit.OSCAddressPattern("/vibeid/track/prompt5"), values: [prompt5])
            send(prompt5Msg, to: host, port: port)
        }
        if let prompt6 = track.prompt6 {
            let prompt6Msg = OSCKit.OSCMessage(OSCKit.OSCAddressPattern("/vibeid/track/prompt6"), values: [prompt6])
            send(prompt6Msg, to: host, port: port)
        }
        if let prompt7 = track.prompt7 {
            let prompt7Msg = OSCKit.OSCMessage(OSCKit.OSCAddressPattern("/vibeid/track/prompt7"), values: [prompt7])
            send(prompt7Msg, to: host, port: port)
        }
        if let prompt8 = track.prompt8 {
            let prompt8Msg = OSCKit.OSCMessage(OSCKit.OSCAddressPattern("/vibeid/track/prompt8"), values: [prompt8])
            send(prompt8Msg, to: host, port: port)
        }
        if let prompt9 = track.prompt9 {
            let prompt9Msg = OSCKit.OSCMessage(OSCKit.OSCAddressPattern("/vibeid/track/prompt9"), values: [prompt9])
            send(prompt9Msg, to: host, port: port)
        }
        if let prompt10 = track.prompt10 {
            let prompt10Msg = OSCKit.OSCMessage(OSCKit.OSCAddressPattern("/vibeid/track/prompt10"), values: [prompt10])
            send(prompt10Msg, to: host, port: port)
        }
    }

    /// Sends a listening status message
    func sendStatusMessage(status: String, host: String, port: Int) {
        guard !host.isEmpty, port > 0, port <= 65535 else {
            return
        }
        
        let statusMsg = OSCKit.OSCMessage(OSCKit.OSCAddressPattern("/vibeid/status"), values: [status])
        send(statusMsg, to: host, port: port)
    }
    
    /// Sends a ping signal for testing
    func sendPing(to host: String, port: Int) {
        guard !host.isEmpty, port > 0, port <= 65535 else {
            return
        }
        
        let pingMsg = OSCKit.OSCMessage(OSCKit.OSCAddressPattern("/vibeid/test"), values: ["ping"])
        send(pingMsg, to: host, port: port)
    }
    
    /// Gets the local IP address of the device (useful for diagnostics)
    func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0 else {
            return nil
        }
        
        guard let firstAddr = ifaddr else {
            return nil
        }
        
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            
            // Check if we have an IPv4 or IPv6 address
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                
                // Check if the interface is "en0" (WiFi usually) or "en1" or "pdp_ip0" (cellular)
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "en1" || name == "pdp_ip0" {
                    
                    // Convert the address to readable form
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                               &hostname, socklen_t(hostname.count),
                               nil, socklen_t(0), NI_NUMERICHOST)
                    
                    let ipAddress = String(cString: hostname)
                    
                    // We only return IPv4 addresses that are not loopback
                    if addrFamily == UInt8(AF_INET) && ipAddress != "127.0.0.1" {
                        address = ipAddress
                        break
                    }
                }
            }
        }
        
        freeifaddrs(ifaddr)
        return address
    }
    
    /// Performs a network diagnostic for the OSC connection
    func diagnosticNetwork(to host: String, port: Int) -> String {
        var report = "=== OSC NETWORK DIAGNOSTIC ===\n\n"
        
        // 1. Check connection parameters
        report += "CONNECTION PARAMETERS:\n"
        report += "- Target host: \(host)\n"
        report += "- Target port: \(port)\n\n"
        
        // 2. Check local IP address
        report += "LOCAL IP ADDRESS:\n"
        if let localIP = getLocalIPAddress() {
            report += "- IP of this device: \(localIP)\n\n"
        } else {
            report += "- Unable to determine local IP\n\n"
        }
        
        // 3. Test OSC connection
        report += "OSC CONNECTION TEST:\n"
        let connectionSuccess = testConnection(to: host, port: port)
        report += "- OSC connection test: \(connectionSuccess ? "SUCCESS ✓" : "FAILURE ✗")\n\n"
        
        // 4. Suggestions
        report += "SUGGESTIONS:\n"
        if !connectionSuccess {
            report += "- Check that the target device is turned on\n"
            report += "- Check that both devices are on the same network\n"
            report += "- Check that the firewall is not enabled\n"
            report += "- Try using the IP address 255.255.255.255 for broadcasting\n"
            report += "- Make sure the OSC port is open on the target device\n"
        } else {
            report += "- Connection successful, everything seems functional\n"
            report += "- If you don't receive messages, check\n  your OSC receiver configuration\n"
        }
        
        return report
    }
}


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

@MainActor
class OSCManager {

    private let oscClient = OSCClient()

    // Enable detailed logging
    private var verboseLogging: Bool = true

    init() {
        print("OSCManager Initialized")
    }

    /// Sends a single OSC message in a simple and direct way.
    func send(_ message: OSCMessage, to host: String, port: Int) {
        guard !host.isEmpty, port > 0, port <= 65535 else {
            print("OSCManager Error: Host (\(host)) or Port (\(port)) invalid.")
            return
        }
        
        print("OSCManager: Sending message \(message.addressPattern) to \(host):\(port)")
        
        // Display message values if verbose logging is enabled
        if verboseLogging {
            let valuesString = message.values.map { 
                if let strVal = $0 as? String {
                    return "\"\(strVal)\""
                } else {
                    return "\($0)"
                }
            }.joined(separator: ", ")
            
            print("OSCManager DEBUG: Sending \(message.addressPattern) -> [\(valuesString)]")
        }
        
        // Direct synchronous approach that has worked in previous versions
        do {
            try oscClient.send(message, to: host, port: UInt16(port))
            print("OSCManager: Message sent successfully")
        } catch {
            print("OSCManager: ERROR sending OSC: \(error.localizedDescription)")
            
            // Try a second time after a short delay
            do {
                Thread.sleep(forTimeInterval: 0.05)
                try oscClient.send(message, to: host, port: UInt16(port))
                print("OSCManager: Second attempt successful")
            } catch {
                print("OSCManager: COMPLETE FAILURE sending OSC: \(error.localizedDescription)")
            }
        }
    }

    /// Tests the OSC connection by sending a simple message.
    func testConnection(to host: String, port: Int) -> Bool {
        guard !host.isEmpty, port > 0, port <= 65535 else {
            print("OSCManager Test: Invalid configuration")
            return false
        }
        
        print("OSCManager: Testing OSC connection to \(host):\(port)")
        
        // Create a simple test message
        let testMsg = OSCMessage(OSCAddressPattern("/vibeid/test"), values: ["ping"])
        
        do {
            try oscClient.send(testMsg, to: host, port: UInt16(port))
            print("OSCManager: Connection test successful")
            return true
        } catch {
            print("OSCManager: Connection test FAILED: \(error.localizedDescription)")
            return false
        }
    }

    /// Sends identified track information via OSC.
    func sendTrackInfo(track: TrackInfo, host: String, port: Int) {
        print("OSCManager: Sending track info via OSC")
        
        // Verify validity
        guard !host.isEmpty, port > 0, port <= 65535 else {
            print("OSCManager: Invalid OSC configuration for sendTrackInfo")
            return
        }
        
        // Send title
        if let title = track.title {
            let addr = OSCAddressPattern("/vibeid/track/title")
            let titleMsg = OSCMessage(addr, values: [title])
            send(titleMsg, to: host, port: port)
        }
        
        // Send artist
        if let artist = track.artist {
            let addr = OSCAddressPattern("/vibeid/track/artist")
            let artistMsg = OSCMessage(addr, values: [artist])
            send(artistMsg, to: host, port: port)
        }
        
        // Send genre
        if let genre = track.genre, !genre.isEmpty {
            let addr = OSCAddressPattern("/vibeid/track/genre")
            let genreMsg = OSCMessage(addr, values: [genre])
            send(genreMsg, to: host, port: port)
        }
        
        // Send BPM
        if let bpm = track.bpm {
            let addr = OSCAddressPattern("/vibeid/track/bpm")
            let bpmMsg = OSCMessage(addr, values: [Float(bpm)])
            send(bpmMsg, to: host, port: port)
        }
        
        // Send energy
        if let energy = track.energy {
            let addr = OSCAddressPattern("/vibeid/track/energy")
            let energyMsg = OSCMessage(addr, values: [Float(energy)])
            send(energyMsg, to: host, port: port)
        }
        
        // Send danceability
        if let danceability = track.danceability {
            let addr = OSCAddressPattern("/vibeid/track/danceability")
            let danceabilityMsg = OSCMessage(addr, values: [Float(danceability)])
            send(danceabilityMsg, to: host, port: port)
        }
        
        // Send artwork URL
        if let artworkURL = track.artworkURL?.absoluteString {
            let addr = OSCAddressPattern("/vibeid/track/artwork")
            let artworkMsg = OSCMessage(addr, values: [artworkURL])
            send(artworkMsg, to: host, port: port)
        }
        
        print("OSCManager: Track info sending completed.")
    }

    /// Sends a manual prompt entered by the user via OSC.
    func sendManualPrompt(prompt: String, host: String, port: Int) {
        print("OSCManager: Sending manual prompt via OSC: \"\(prompt)\"")
        
        // Verify validity
        guard !host.isEmpty, port > 0, port <= 65535 else {
            print("OSCManager: Invalid OSC configuration for sendManualPrompt")
            return
        }
        
        // Standard format with prefix
        let addr = OSCAddressPattern("/vibeid/prompt")
        let promptMsg = OSCMessage(addr, values: [prompt])
        send(promptMsg, to: host, port: port)
    }
    
    /// Sends a listening status message
    func sendStatusMessage(status: String, host: String, port: Int) {
        guard !host.isEmpty, port > 0, port <= 65535 else {
            return
        }
        
        let statusMsg = OSCMessage(OSCAddressPattern("/vibeid/status"), values: [status])
        send(statusMsg, to: host, port: port)
    }
    
    /// Sends a ping signal for testing
    func sendPing(to host: String, port: Int) {
        guard !host.isEmpty, port > 0, port <= 65535 else {
            return
        }
        
        let pingMsg = OSCMessage(OSCAddressPattern("/vibeid/test"), values: ["ping"])
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

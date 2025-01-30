//
//  RoomManager.swift
//  BeaconSyncAR-iBeacon-ARCore
//
//  Created by Maitree Hirunteeyakul on 11/2/24.
//
import Foundation
import Combine
import CoreLocation

struct IBeaconData: Codable, Hashable {
    let uuid: UUID
    let major: Int
    let minor: Int
    
    init(from beacon: CLBeacon) {
        self.uuid = beacon.uuid
        self.major = Int(truncating: beacon.major)
        self.minor = Int(truncating: beacon.minor)
    }
}

struct Room: Codable, Hashable {
    let id: UUID
    let name: String
}

class RoomManager: ObservableObject {
    @Published private(set) var currentRoom: Room? = nil
    
    private var beaconManager: BeaconManager
    private var subscriptions = Set<AnyCancellable>()
    private var beaconRoomMap = [IBeaconData: Room?]()
    
    init() {
        Logger.addLog(label: "Initialize RoomManager")
        self.beaconManager = BeaconManager()
        beaconManager.startMonitoringBeacon(
            uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"
        )
        setupBindings()
        Logger.addLog(label: "Fininshed Initialize RoomManager")
    }
    
    private func setupBindings() {
        beaconManager.$beacons
            .sink { [weak self] proximityBeacons in
                self?.handleBeaconUpdates(proximityBeacons!)
            }
            .store(in: &subscriptions)
    }
    
    private func handleBeaconUpdates(_ proximityBeacons: [CLProximity: [CLBeacon]]) {
        for beacon in proximityBeacons.values.flatMap({ $0 }) {
            let iBeaconData = IBeaconData(from: beacon)
            if beaconRoomMap[iBeaconData] == nil {
                fetchRoomInfo(for: iBeaconData)
            }
        }
        
        computeRoom()
    }
    
    private func fetchRoomInfo(for beaconData: IBeaconData) {
        let url = URL(string: "https://api.fyp.maitree.dev/ibeacon/getRoom")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        request.httpBody = try? JSONEncoder().encode(beaconData)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Asynchronous fetching of room info
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            if let data = data,
               let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               let room = try? JSONDecoder().decode(Room.self, from: data) {
                DispatchQueue.main.async {
                    self.beaconRoomMap[beaconData] = room
                    self.computeRoom()
                }
            } else {
                // If there was an error or a non-200 status code, store nil in the map
                DispatchQueue.main.async {
                    self.beaconRoomMap[beaconData] = nil
                    self.computeRoom()
                }
            }
        }.resume()
    }
    
    private func computeRoom() {
        var roomFrequency = [Room: Int]()
        
        // Determine all potential beacons involved with proximity ordering
        let expectedBeacons = AllCLProximity
            .compactMap { proximity in
                beaconManager.beacons[proximity]
            }
            .flatMap { $0 }
        
        // Check if we have attempted to fetch data for all expected beacons, regardless of success
        let allRoomsFetched = expectedBeacons.allSatisfy { beacon in
            beaconRoomMap.keys.contains(IBeaconData(from: beacon))
        }
        
        if !allRoomsFetched {
            // If not all room fetch attempts have been completed, wait and try later
            return
        }
        
        // Gather all rooms known from the nearest proximity with non-empty room info
        let nearestRooms: [Room] = AllCLProximity
            .compactMap { proximity in
                beaconManager.beacons[proximity]?.compactMap { beacon in
                    beaconRoomMap[IBeaconData(from: beacon)]
                }.compactMap { $0 }
            }
            .first { !$0.isEmpty } ?? []
        
        // Count frequencies of each room
        for room in nearestRooms {
            roomFrequency[room, default: 0] += 1
        }
        
        // Determine the most common room
        if let mostCommonRoom = roomFrequency.max(by: { $0.value < $1.value }).map({ $0.key }) {
            if roomFrequency.filter({ $0.value == roomFrequency[mostCommonRoom]! }).count > 1,
               let lastRoom = currentRoom,
               roomFrequency[lastRoom] == roomFrequency[mostCommonRoom] {
                // Do nothing the previous room is still dominant.
            } else {
                if currentRoom != mostCommonRoom {
                    // Update only nesesary
                    currentRoom = mostCommonRoom
                    Logger.addLog(label: "Room Update", content: mostCommonRoom)
                }
            }
        } else {
            currentRoom = nil
        }
    }
    
}


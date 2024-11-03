//
//  CloudAnchorsManager.swift
//  BeaconSyncAR-iBeacon-ARCore
//
//  Created by Maitree Hirunteeyakul on 11/2/24.
//
import Foundation
import Combine
import ARKit

class CloudAnchorsManager {
    
    private var roomManager: RoomManager
    private var arViewModel: ARViewModel
    private var subscriptions = Set<AnyCancellable>()
    private var currentRoom: Room?
    
    init(roomManager: RoomManager, arViewModel: ARViewModel) {
        self.roomManager = roomManager
        self.arViewModel = arViewModel
        setupBindings()
    }
    
    private func setupBindings() {
        roomManager.$currentRoom
            .compactMap { $0 }
            .sink { [weak self] room in
                Task {
                    await self?.handleRoomUpdates(in: room)
                }
            }
            .store(in: &subscriptions)
    }
    
    private func handleRoomUpdates(in room: Room) async {
        currentRoom = room
        pullAndResloveCloudAnchors(in: room)
    }
    
    private func pullCloudAnchorsIds(in room: Room) async throws -> [String] {
        let urlString = "https://api.fyp.maitree.dev/room/\(room.id.uuidString)/CloudAnchor/list"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        struct CloudAnchorEntity: Codable {
            let anchorId: String
            let id: UUID
        }
        
        typealias CloudAnchorListRespond = [CloudAnchorEntity]
        let cloudAnchorList = try JSONDecoder().decode(CloudAnchorListRespond.self, from: data)
        return cloudAnchorList.map{$0.anchorId}
    }
    
    private func pullAndResloveCloudAnchors(in room: Room) {
        print("PULLING room: \(room.name)")
        Task{
            do {
                let cloudAnchorsIds = try await pullCloudAnchorsIds(in: room)
                cloudAnchorsIds.forEach { cloudAnchorsId in
                    print("Backend: cloudAnchorsId: \(cloudAnchorsId)")
                    arViewModel.resolveAnchor(cloudAnchorsId)
                }
            } catch {
                print("Error can't pull cloud anchor ids from backend: \(error.localizedDescription)")
            }
        }
    }
    
    private func uploadCloudAnchorToBackend(_ cloudId: String) async throws {
        
        guard let room = currentRoom else {
            throw NSError(domain: "Room", code: 0, userInfo: [NSLocalizedDescriptionKey: "No Room are avaliable."])
        }
        
        let urlString = "https://api.fyp.maitree.dev/room/\(room.id.uuidString)/CloudAnchor/new"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        struct UploadCloudAnchorParam: Codable{
            let anchorId: String
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try? JSONEncoder().encode(UploadCloudAnchorParam(anchorId: cloudId))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
    }
    
    public func uploadCloudAnchor(_ cloudId: String){
        print("UPLOADING: \(cloudId)@\(currentRoom?.name ?? "Unknown Room")")
        Task{
            do {
                try await uploadCloudAnchorToBackend(cloudId)
                print("UPLOADED: \(cloudId)")
            } catch {
                print("Error can't upload cloud anchor id to backend: \(error.localizedDescription)")
            }
        }
    }
    
}


//
//  ContentView.swift
//  BeaconSyncAR-iBeacon-ARCore
//
//  Created by Maitree Hirunteeyakul on 11/2/24.
//
import SwiftUI
import ARKit

struct ContentView: View {
    @StateObject private var arViewModel: ARViewModel = ARViewModel()
    @StateObject private var roomManager: RoomManager = RoomManager()
    
    init() {
        let arViewModel = ARViewModel()
        let roomManager = RoomManager()
        let cloudAnchorsManager = CloudAnchorsManager(roomManager: roomManager, arViewModel: arViewModel)
        
        arViewModel.setCloudAnchorsManager(cloudAnchorsManager)
        
        _arViewModel = StateObject(wrappedValue: arViewModel)
        _roomManager = StateObject(wrappedValue: roomManager)
    }
    
    var roomName:String? { roomManager.currentRoom?.name }
    
    var session:ARSession? { arViewModel.sceneView?.session }
    
    var body: some View {
        ZStack{
            ARViewContainer(arViewModel: arViewModel).ignoresSafeArea(.all)
            VStack{
                VStack{
                    if let roomName {
                        VStack{
                            Text("Welcome To").font(.caption2)
                            Text("\(roomName)").bold()
                        }
                        .foregroundColor(.white)
                        .padding(12)
                        .background(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding()
                Spacer()
            }
        }
        
    }
}

#Preview {
    ContentView()
}


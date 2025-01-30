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
    
    @ObservedObject var logger: Logger = Logger.get()
    
    init(logger: Logger? = nil) {
        let arViewModel = ARViewModel()
        let roomManager = RoomManager()
        let cloudAnchorsManager = CloudAnchorsManager(roomManager: roomManager, arViewModel: arViewModel)
        
        arViewModel.setCloudAnchorsManager(cloudAnchorsManager)
        
        _arViewModel = StateObject(wrappedValue: arViewModel)
        _roomManager = StateObject(wrappedValue: roomManager)
        
        if let logger {
            logger.addLog(label: "ContentView Initialize", content: "Mocked Logger")
            _logger = ObservedObject(wrappedValue: logger)
        }
        else {
            let logger = Logger.get()
            logger.addLog(label: "ContentView Initialize")
            _logger = ObservedObject(wrappedValue:logger)
        }
    }
    
    var roomName:String? { roomManager.currentRoom?.name }
    
    var session:ARSession? { arViewModel.sceneView?.session }
    
    var body: some View {
        NavigationStack {
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
                
                VStack{
                    Spacer()
                    HStack{
                        NavigationLink(destination: LogView(logger: logger)) {
                            Text("Open Log").padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .opacity(1)
                        }.navigationBarTitleDisplayMode(.automatic)
                    }
                    
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let logger = Logger.sampleLogger()
        return ContentView(logger: logger)
    }
}



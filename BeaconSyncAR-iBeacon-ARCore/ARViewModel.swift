//
//  ARViewModel.swift
//  BeaconSyncAR-iBeacon-ARCore
//
//  Created by Maitree Hirunteeyakul on 11/2/24.
//
import SwiftUI
import SceneKit
import ARKit
import ARCore

class ARViewModel: NSObject, ObservableObject {
    @Published var sceneView: ARSCNView?
    @Published var worldMappingStatus: ARFrame.WorldMappingStatus = .notAvailable
    var modelNode: SCNNode!
    private var garSession: GARSession!
    private var cloudAnchorsManager: CloudAnchorsManager?
    private var resolvedAnchors: [UUID: ARAnchor] = [:]
    
    override init() {
        super.init()
        sceneView = makeARView()
        loadModel()
        setupGestureRecognizer()
        setupGARSession()
    }
    
    var defaultConfiguration: ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        configuration.environmentTexturing = .automatic
        return configuration
    }
    
    func makeARView() -> ARSCNView {
        let sceneView = ARSCNView(frame: .zero)
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.session.run(defaultConfiguration, options: [.removeExistingAnchors,.resetSceneReconstruction,.resetTracking])
        return sceneView
    }
    
}

// ARCore
extension ARViewModel {
    
    func setCloudAnchorsManager(_ manager: CloudAnchorsManager) {
        self.cloudAnchorsManager = manager
    }
    
    private static func stringFromCloudState(_ cloudState: GARCloudAnchorState) -> String {
        switch cloudState {
        case .none:
            return "None"
        case .success:
            return "Success"
        case .errorInternal:
            return "ErrorInternal"
        case .errorNotAuthorized:
            return "ErrorNotAuthorized"
        case .errorResourceExhausted:
            return "ErrorResourceExhausted"
        case .errorHostingDatasetProcessingFailed:
            return "ErrorHostingDatasetProcessingFailed"
        case .errorCloudIdNotFound:
            return "ErrorCloudIdNotFound"
        case .errorResolvingSdkVersionTooNew:
            return "ErrorResolvingSdkVersionTooNew"
        case .errorResolvingSdkVersionTooOld:
            return "ErrorResolvingSdkVersionTooOld"
        case .errorHostingServiceUnavailable:
            return "ErrorHostingServiceUnavailable"
        default:
            // Not handling deprecated enum values that will never be returned.
            return "Unknown"
        }
    }
    
    private func setupGARSession() {
        do {
            let GOOGLE_ARCORE_API_KEY =  Bundle.main.object(forInfoDictionaryKey: "GOOGLE_ARCORE_API_KEY") as! String
            print(GOOGLE_ARCORE_API_KEY)
            garSession = try GARSession(apiKey: GOOGLE_ARCORE_API_KEY, bundleIdentifier: nil)
            let configuration = GARSessionConfiguration()
            configuration.cloudAnchorMode = .enabled
            var error: NSError? = nil
            garSession.setConfiguration(configuration, error: &error)
            if let error {
                print("Failed to configure the GARSession: \(error)")
            }
        } catch {
            print("Failed to create GARSession: \(error)")
        }
    }
    
    private func hostCloudAnchor(anchor: ARAnchor) {
        guard let garSession = garSession else { return }
        
        do{
            _ = try garSession.hostCloudAnchor(anchor, ttlDays: 1) { [weak self] cloudId, cloudState in
                self?.finishHosting(cloudId: cloudId, cloudState: cloudState)
            }
        }catch{
            print("Failed to host cloud anchor: \(error.localizedDescription)")
        }
    }
    
    private func finishHosting(cloudId: String?, cloudState: GARCloudAnchorState){
        
        if let cloudId = cloudId {
            cloudAnchorsManager?.uploadCloudAnchor(cloudId)
        }
        
        print("cloudId \(cloudId ?? "N/A"), cloudState \(ARViewModel.stringFromCloudState(cloudState))")
    }
    
    public func resolveAnchor(_ cloudId: String) {
        guard let garSession = garSession else { return }
        do {
            _ = try garSession.resolveCloudAnchor(cloudId) { [weak self] anchor, cloudState in
                self?.finishResolving(cloudId: cloudId, cloudState: cloudState)
            }
        }
        catch{
            print("Failed to reslove cloud anchor: \(error.localizedDescription)")
        }
    }
    private func finishResolving(cloudId: String?, cloudState: GARCloudAnchorState){
        print("Resloved: cloudId \(cloudId ?? "N/A"), cloudState \(ARViewModel.stringFromCloudState(cloudState))")
    }
    
    private func updatedAnchors(_ anchors: [GARAnchor]) {
        for garAnchor in anchors {
            print("GAR: update garAnchor: \(garAnchor.identifier)")
            
            if let resolvedAnchor = resolvedAnchors[garAnchor.identifier] {
                sceneView?.session.remove(anchor: resolvedAnchor)
                resolvedAnchors.removeValue(forKey: garAnchor.identifier)
            }
            
            let bunnyAnchor = ARAnchor(name: "bunny", transform: garAnchor.transform)
            sceneView?.session.add(anchor: bunnyAnchor)
            resolvedAnchors[garAnchor.identifier] = bunnyAnchor
        }
    }
}

// FeaturePoints
extension ARViewModel: ARSessionDelegate, ARSCNViewDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        self.worldMappingStatus = frame.worldMappingStatus
        self.plotFeaturePoints(frame: frame)
        
        // ARCore
        guard let garFrame = try? garSession?.update(frame) else { return }
        updatedAnchors(garFrame.updatedAnchors)
    }
    
    private func plotFeaturePoints(frame: ARFrame) {
        guard let rawFeaturePoints = frame.rawFeaturePoints else { return }
        
        let points = rawFeaturePoints.points
        
        sceneView?.scene.rootNode.childNodes.filter { $0.name == "FeaturePoint" }.forEach { $0.removeFromParentNode() }
        
        let sphereNode = SCNNode(geometry: SCNSphere(radius: 0.001))
        sphereNode.geometry?.firstMaterial?.diffuse.contents = UIColor.green
        
        points.forEach { point in
            let clonedSphereNode = sphereNode.clone()
            clonedSphereNode.name = "FeaturePoint"
            clonedSphereNode.position = SCNVector3(point.x, point.y, point.z)
            sceneView?.scene.rootNode.addChildNode(clonedSphereNode)
        }
    }
}

// Bunny Hit-Test
extension ARViewModel {
    
    private func placeModel(at raycastResult: ARRaycastResult) {
        let bunnyAnchor = ARAnchor(name: "bunny", transform: raycastResult.worldTransform)
        hostCloudAnchor(anchor: bunnyAnchor)
        sceneView?.session.add(anchor: bunnyAnchor)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard anchor.name == "bunny",
              let modelNode = modelNode?.clone() else {
            return
        }
        
        modelNode.position = SCNVector3Zero
        modelNode.eulerAngles = SCNVector3(-Double.pi / 2, -Double.pi / 2, 0)
        
        node.addChildNode(modelNode)
    }
}

// Guesture Set-up Hit-Test
extension ARViewModel {
    
    func setupGestureRecognizer() {
        guard let sceneView = sceneView else { return }
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(gestureRecognizer:)))
        sceneView.addGestureRecognizer(tapGestureRecognizer)
    }
    
    @objc func handleTap(gestureRecognizer: UITapGestureRecognizer) {
        let touchLocation = gestureRecognizer.location(in: sceneView)
        
        guard let raycastQuery = sceneView?.raycastQuery(from: touchLocation, allowing: .estimatedPlane, alignment: .horizontal) else {
            return
        }
        
        guard let raycastResult = sceneView?.session.raycast(raycastQuery).first else {
            return
        }
        
        placeModel(at: raycastResult)
    }
}

// 3D Model Loading
extension ARViewModel {
    private func loadModel() {
        guard let modelScene = SCNScene(named: "stanford-bunny.usdz"),
              let node = modelScene.rootNode.childNodes.first else {
            print("Failed to load the USDZ model.")
            return
        }
        modelNode = node
    }
}

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var arViewModel: ARViewModel
    
    func makeUIView(context: Context) -> ARSCNView {
        return arViewModel.sceneView ?? ARSCNView()
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {}
}



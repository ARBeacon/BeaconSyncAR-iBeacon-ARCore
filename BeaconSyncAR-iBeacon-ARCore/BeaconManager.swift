//
//  BeaconManager.swift
//  BeaconSyncAR-iBeacon-ARCore
//
//  Created by Maitree Hirunteeyakul on 11/2/24.
//
import Foundation
import CoreLocation

let AllCLProximity: [CLProximity] = [.immediate, .near, .far, .unknown]
let CLProximityLabelPairs: [CLProximity: String] = [.immediate: "Immediate", .near: "Near", .far: "Unknown"]

class BeaconManager: NSObject, ObservableObject {
    private var locationManager: CLLocationManager!
    private var beaconConstraints: [CLBeaconIdentityConstraint: [CLBeacon]]!
    @Published private(set) var beacons: [CLProximity: [CLBeacon]]!
    
    override init() {
        super.init()
        Logger.addLog(label: "Initialize BeaconManager")
        setupLocationManager()
        Logger.addLog(label: "Fininshed Initialize BeaconManager")
    }
    
    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager.delegate = self
        beaconConstraints = [CLBeaconIdentityConstraint: [CLBeacon]]()
        beacons = [CLProximity: [CLBeacon]]()
    }
    
    func startMonitoringBeacon(uuidString: String) {
        guard let uuid = UUID(uuidString: uuidString) else { return }
        
        locationManager.requestWhenInUseAuthorization()
        
        let constraint = CLBeaconIdentityConstraint(uuid: uuid)
        beaconConstraints[constraint] = []
        let beaconRegion = CLBeaconRegion(beaconIdentityConstraint: constraint, identifier: uuid.uuidString)
        locationManager.startMonitoring(for: beaconRegion)
    }
}

extension BeaconManager: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        guard let beaconRegion = region as? CLBeaconRegion else { return }
        
        if state == .inside {
            manager.startRangingBeacons(satisfying: beaconRegion.beaconIdentityConstraint)
        } else {
            manager.stopRangingBeacons(satisfying: beaconRegion.beaconIdentityConstraint)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didRange beacons: [CLBeacon], satisfying beaconConstraint: CLBeaconIdentityConstraint) {
        beaconConstraints[beaconConstraint] = beacons

        var newProximityBeacons = [CLProximity: [CLBeacon]]()
        var allBeacons = [CLBeacon]()
        
        for regionResult in beaconConstraints.values {
            allBeacons.append(contentsOf: regionResult)
        }
        
        for range in AllCLProximity {
            let proximityBeacons = allBeacons.filter { $0.proximity == range }
            if !proximityBeacons.isEmpty {
                newProximityBeacons[range] = proximityBeacons
            }
        }

        if newProximityBeacons != self.beacons {
            DispatchQueue.main.async {
                self.beacons = newProximityBeacons
            }
        }
    }
}


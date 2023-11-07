//
// Copyright (c) 2023, Beau Butner
// All rights reserved.

// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree.
//


import Foundation
import Supabase
import SwiftUI

@Observable
final class MainViewModel {
    let api: SpoolSenseApi
    var filaments = [Filament]()
    var spools = [Spool]()
    var session: Session?
    
    private(set) var initialDataLoaded: Bool = false
    private(set) var refreshingFilaments: Bool = false
    private(set) var refreshingSpools: Bool = false
    
    init(api: SpoolSenseApi) {
        self.api = api
    }
    
    func refreshFilaments() async {
        refreshingFilaments = true
        
        let apiFilaments = await api.fetchFilaments()
        
        let removedFilamentIds = filaments.filter { current in
            !apiFilaments.contains { api in
                api.id == current.id
            }
        }
            .map { $0.id }
        
        filaments.removeAll { removedFilamentIds.contains($0.id) }
        
        apiFilaments.forEach { apiFilament in
            let existingFilament = filaments.first(where: { $0.id == apiFilament.id })
            
            if existingFilament != nil {
                existingFilament?.updateFromRefresh(api: apiFilament)
            } else {
                filaments.append(Filament(api: apiFilament))
            }
        }
        
        refreshingFilaments = false
    }
    
    func refreshSpools() async {
        refreshingSpools = true
        
        let apiSpools = await api.fetchSpools()
        
        let removedSpoolIds = spools.filter { currentSpool in
            !apiSpools.contains { apiSpool in
                apiSpool.id == currentSpool.id
            }
        }
            .map { $0.id }
        
        spools.removeAll { removedSpoolIds.contains($0.id) }
        
        for apiSpool in apiSpools {
            let existingSpool = spools.first(where: { $0.id == apiSpool.id })
            let linkedFilament = filaments.first(where: { $0.id == apiSpool.filamentId })
                        
            if linkedFilament != nil {
                let lengthRemaining = await api.fetchSpoolLengthRemaining(spoolId: apiSpool.id)
                
                if existingSpool != nil {
                    existingSpool!.updateFromRefresh(api: apiSpool, filament: linkedFilament!, newLengthRemaining: lengthRemaining)
                } else {
                    spools.append(Spool(api: apiSpool, filament: linkedFilament!, lengthRemaining: lengthRemaining))
                }
            }
        }
        
        refreshingSpools = false
    }
    
    func loadInitialData() async {
        await api.fetchFilaments().map { Filament(api: $0) }
            .forEach {
                self.filaments.append($0)
            }
        
        let loadedSpools = await api.fetchSpools()
        
        for spool in loadedSpools {
            let linkedFilament = self.filaments.first { $0.id == spool.filamentId }
            
            if linkedFilament == nil {
                continue
            }
            
            let lengthRemaining = await api.fetchSpoolLengthRemaining(spoolId: spool.id)
            
            self.spools.append(Spool(api: spool, filament: linkedFilament!, lengthRemaining: lengthRemaining))
        }
        
        self.initialDataLoaded = true
    }
}

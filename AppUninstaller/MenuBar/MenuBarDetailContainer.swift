import SwiftUI

struct MenuBarDetailContainer: View {
    @ObservedObject var manager: MenuBarManager
    @ObservedObject var systemMonitor: SystemMonitorService
    var route: MenuBarRoute
    
    var body: some View {
        ZStack {
            Color(hex: "1C0C24").ignoresSafeArea()
            
            switch route {
            case .storage:
                StorageDetailView(manager: manager)
            case .memory:
                MemoryDetailView(manager: manager, systemMonitor: systemMonitor)
            case .battery:
                BatteryDetailView(manager: manager, systemMonitor: systemMonitor)
            case .cpu:
                CPUDetailView(manager: manager, systemMonitor: systemMonitor)
            case .network:
                NetworkDetailView(manager: manager, systemMonitor: systemMonitor)
            default:
                EmptyView()
            }
        }
        .frame(width: 360, height: 620) // Fixed size for detail window
    }
}

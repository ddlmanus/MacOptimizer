import Foundation

struct PortItem: Identifiable {
    let id = UUID()
    let command: String
    let pid: String
    let user: String
    let fd: String
    let type: String
    let device: String
    let sizeOff: String
    let node: String
    let name: String // Protocol/Port info
}

class PortScannerService: ObservableObject {
    @Published var ports: [PortItem] = []
    @Published var isScanning = false
    
    func scanPorts() async {
        await MainActor.run { isScanning = true }
        
        let task = Process()
        task.launchPath = "/usr/sbin/lsof"
        task.arguments = ["-i", "-P", "-n"] // Internet files, No port names, No host names
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: "\n")
                // Skip header line
                var items: [PortItem] = []
                for (index, line) in lines.enumerated() {
                    if index == 0 || line.isEmpty { continue }
                    
                    // lsof output is column based but variable width. 
                    // COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
                    // Use regex or splitting by whitespace (careful with spaces in COMMAND, usually lsof truncates or escapes, but simplified split is often okay for first pass)
                    let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                    if parts.count >= 9 {
                        // Assuming standard lsof output format
                        let item = PortItem(
                            command: String(parts[0]),
                            pid: String(parts[1]),
                            user: String(parts[2]),
                            fd: String(parts[3]),
                            type: String(parts[4]),
                            device: String(parts[5]),
                            sizeOff: String(parts[6]),
                            node: String(parts[7]),
                            name: parts[8...].joined(separator: " ")
                        )
                        items.append(item)
                    }
                }
                
                await MainActor.run {
                    self.ports = items
                    self.isScanning = false
                }
            }
        } catch {
            print("Port Scan Error: \(error)")
            await MainActor.run { isScanning = false }
        }
    }
}

import Foundation
import Combine

class SystemMonitorService: ObservableObject {
    @Published var cpuUsage: Double = 0.0
    @Published var memoryUsage: Double = 0.0 // Percentage
    @Published var memoryUsedString: String = "0 GB"
    @Published var memoryTotalString: String = "0 GB"
    
    private var timer: Timer?
    
    init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        updateStats()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateStats()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateStats() {
        // CPU Usage (Simplified using top for now to avoid complex Mach calls issues in pure Swift script context initially, 
        // but robust implementation would use host_processor_info. Let's try to parse top -l 1 output specifically designed for machine reading if possible, 
        // or just standard parsing.)
        // Actually, let's use a simpler bash command approach which is safer/easier to debug in this agent environment.
        // `ps -A -o %cpu | awk '{s+=$1} END {print s}'` gives total CPU usage sum (can be > 100% on multi-core).
        
        let cpuTask = Process()
        cpuTask.launchPath = "/bin/bash"
        cpuTask.arguments = ["-c", "ps -A -o %cpu | awk '{s+=$1} END {print s}'"]
        
        let pipe = Pipe()
        cpuTask.standardOutput = pipe
        
        do {
            try cpuTask.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               let totalCPU = Double(output) {
                // Normalize by core count approximately? Or just show raw. 
                // Let's normalize by active core count to get 0-100% range typically expected by users.
                let coreCount = Double(ProcessInfo.processInfo.activeProcessorCount)
                DispatchQueue.main.async {
                    self.cpuUsage = min((totalCPU / coreCount) / 100.0, 1.0)
                }
            }
        } catch {
            print("CPU Scan Error: \(error)")
        }
        
        // Memory Usage
        // Uses `vm_stat`
        let memTask = Process()
        memTask.launchPath = "/usr/bin/vm_stat"
        
        let memPipe = Pipe()
        memTask.standardOutput = memPipe
        
        do {
            try memTask.run()
            let data = memPipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: "\n")
                var pageSize: UInt64 = 4096 // Default
                var pagesFree: UInt64 = 0
                var pagesActive: UInt64 = 0
                var pagesInactive: UInt64 = 0
                var pagesSpeculative: UInt64 = 0
                var pagesWired: UInt64 = 0
                var pagesCompressed: UInt64 = 0
                
                for line in lines {
                    if line.contains("page size of") {
                        if let last = line.split(separator: " ").last, let size = UInt64(last) {
                            pageSize = size
                        }
                    } else if line.contains("Pages free") {
                        pagesFree = extractPageCount(line)
                    } else if line.contains("Pages active") {
                        pagesActive = extractPageCount(line)
                    } else if line.contains("Pages inactive") {
                        pagesInactive = extractPageCount(line)
                    } else if line.contains("Pages speculative") {
                        pagesSpeculative = extractPageCount(line)
                    } else if line.contains("Pages wired down") {
                        pagesWired = extractPageCount(line)
                    } else if line.contains("Pages occupied by compressor") {
                        pagesCompressed = extractPageCount(line)
                    }
                }
                
                let totalRAM = ProcessInfo.processInfo.physicalMemory
                let usedRAM = (pagesActive + pagesWired + pagesCompressed) * pageSize
                
                DispatchQueue.main.async {
                    self.memoryUsage = Double(usedRAM) / Double(totalRAM)
                    self.memoryUsedString = ByteCountFormatter.string(fromByteCount: Int64(usedRAM), countStyle: .memory)
                    self.memoryTotalString = ByteCountFormatter.string(fromByteCount: Int64(totalRAM), countStyle: .memory)
                }
            }
        } catch {
            print("Memory Scan Error: \(error)")
        }
    }
    
    private func extractPageCount(_ line: String) -> UInt64 {
        let parts = line.components(separatedBy: ":")
        if parts.count == 2 {
            let numberPart = parts[1].replacingOccurrences(of: ".", with: "").trimmingCharacters(in: .whitespaces)
            return UInt64(numberPart) ?? 0
        }
        return 0
    }
}

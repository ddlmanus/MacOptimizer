import SwiftUI
import AppKit

private enum UninstallerReplicaCategory: Hashable {
    case all
    case leftovers
    case suspicious
    case selected
    case appStore
    case otherStore
    case vendor(String)
}

struct UninstallerReplicaView: View {
    @ObservedObject var appScanner: AppScanner
    @ObservedObject private var loc = LocalizationManager.shared

    @State private var category: UninstallerReplicaCategory = .all
    @State private var searchText = ""
    @State private var selectedAppIDs: Set<UUID> = []
    @State private var selectedLeftoverIDs: Set<UUID> = []
    @State private var leftovers: [DeepCleanItem] = []
    @State private var detailedApp: InstalledApp?
    @State private var isLoadingRelatedFiles = false
    @State private var isRemoving = false
    @State private var showRemoveConfirmation = false
    @State private var showResult = false
    @State private var resultMessage = ""
    @State private var orbHovered = false

    private let fileRemover = FileRemover()
    private let vendors = ["Google", "MacPaw", "JetBrains", "其他"]

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                categoryPanel
                    .frame(width: 275)
                    .fixedSize(horizontal: true, vertical: false)

                Rectangle()
                    .fill(Color.white.opacity(0.045))
                    .frame(width: 1)

                contentPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if detailedApp == nil {
                CleanMyMacBottomActionSlot {
                    CleanMyMacBottomActionCluster {
                        orbButton(disabled: currentSelectionCount == 0)
                    } accessory: {
                        if currentSelectionCount > 0 {
                            Text(selectionSummary)
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundColor(.white.opacity(0.66))
                        }
                    }
                }
            }
        }
        .onAppear {
            Task { await loadApplicationsAndRelatedFilesIfNeeded() }
        }
        .alert(localized("确认移除？", "Confirm Removal?"), isPresented: $showRemoveConfirmation) {
            Button(actionTitle, role: .destructive) {
                Task { await removeSelection() }
            }
            Button(localized("取消", "Cancel"), role: .cancel) {}
        } message: {
            Text(confirmationMessage)
        }
        .alert(localized("操作完成", "Operation Complete"), isPresented: $showResult) {
            Button(localized("确定", "OK")) {}
        } message: {
            Text(resultMessage)
        }
        .overlay {
            if isRemoving {
                ZStack {
                    Color.black.opacity(0.22).ignoresSafeArea()
                    VStack(spacing: 14) {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text(localized("正在移入废纸篓…", "Moving to Trash…"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.82))
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 22)
                    .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private var categoryPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                detailedApp = nil
                category = .all
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                    Text(localized("简介", "Intro"))
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.64))
            }
            .buttonStyle(.plain)
            .padding(.leading, 11)
            .padding(.top, 21)
            .padding(.bottom, 18)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    categoryRow(.all, title: localized("所有应用程序", "All Applications"), count: appScanner.apps.count)
                    categoryRow(.leftovers, title: localized("残留项", "Leftovers"), count: leftovers.count)
                    categoryRow(.suspicious, title: localized("可疑项", "Suspicious"), count: suspiciousApps.count)
                    categoryRow(.selected, title: localized("已选中", "Selected"), count: selectedAppIDs.count + selectedLeftoverIDs.count)

                    sectionTitle(localized("商店", "STORE"))
                        .padding(.top, 18)
                    categoryRow(.appStore, title: "App Store", count: appScanner.apps.filter(\.isAppStore).count)
                    categoryRow(.otherStore, title: localized("其他", "Other"), count: appScanner.apps.filter { !$0.isAppStore }.count)

                    sectionTitle(localized("供应商", "VENDORS"))
                        .padding(.top, 18)
                    ForEach(vendors, id: \.self) { vendor in
                        categoryRow(.vendor(vendor), title: vendor, count: apps(forVendor: vendor).count)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 30)
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10.5, weight: .medium))
            .foregroundColor(.white.opacity(0.37))
            .padding(.leading, 9)
            .padding(.bottom, 5)
    }

    private func categoryRow(_ value: UninstallerReplicaCategory, title: String, count: Int) -> some View {
        Button {
            category = value
            detailedApp = nil
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 12.5, weight: category == value ? .semibold : .regular))
                    .foregroundColor(.white.opacity(category == value ? 0.90 : 0.70))
                Spacer()
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.white.opacity(category == value ? 0.78 : 0.57))
                }
            }
            .padding(.horizontal, 9)
            .frame(width: 223, height: 29)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(category == value ? Color.black.opacity(0.14) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(UninstallerCategoryButtonStyle())
    }

    @ViewBuilder
    private var contentPanel: some View {
        if let app = detailedApp {
            appDetailPanel(app)
        } else {
            listPanel
        }
    }

    private var listPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelHeader

            Text(categoryTitle)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 9)
                .padding(.horizontal, 20)

            Text(categoryDescription)
                .font(.system(size: 11.5))
                .foregroundColor(.white.opacity(0.72))
                .padding(.top, 7)
                .padding(.horizontal, 20)

            HStack {
                Spacer()
                Text(localized("排序方式按 名称", "Sort by Name"))
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
            }
            .font(.system(size: 10.5))
            .foregroundColor(.white.opacity(0.52))
            .padding(.top, 38)
            .padding(.horizontal, 20)

            if appScanner.isScanning || isLoadingRelatedFiles && appScanner.apps.isEmpty {
                loadingView
            } else if category == .leftovers {
                leftoverList
            } else {
                appList
            }
        }
    }

    private var panelHeader: some View {
        ZStack(alignment: .topLeading) {
            Text(localized("卸载器", "Uninstaller"))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.56))
                .offset(x: 135)
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10, weight: .medium))
                TextField(localized("搜索", "Search"), text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.80))
            }
            .padding(.horizontal, 10)
            .frame(width: 200, height: 30)
            .background(Color.black.opacity(0.17), in: RoundedRectangle(cornerRadius: 8))
            .offset(x: 255)
        }
        .frame(height: 30)
        .padding(.top, 14)
    }

    private var loadingView: some View {
        VStack(spacing: 10) {
            Spacer()
            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.72)
            Text(localized("正在扫描应用程序及关联文件…", "Scanning apps and related files…"))
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.48))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var appList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(filteredApps) { app in
                    appRow(app)
                }
                if filteredApps.isEmpty {
                    emptyState
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 145)
        }
    }

    private var leftoverList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(filteredLeftovers) { item in
                    Button {
                        toggleLeftover(item)
                    } label: {
                        HStack(spacing: 12) {
                            replicaCheckBox(selected: selectedLeftoverIDs.contains(item.id))
                            Image(systemName: "doc.badge.gearshape")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.70))
                                .frame(width: 28, height: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.86))
                                    .lineLimit(1)
                                Text(item.url.deletingLastPathComponent().path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                                    .font(.system(size: 9.5))
                                    .foregroundColor(.white.opacity(0.36))
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(item.formattedSize)
                                .font(.system(size: 10.5))
                                .foregroundColor(.white.opacity(0.55))
                        }
                        .frame(height: 48)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(UninstallerRowButtonStyle())
                    .scanResultContextMenu(
                        isSelected: selectedLeftoverIDs.contains(item.id),
                        displayName: item.name,
                        url: item.url,
                        onToggleSelection: { toggleLeftover(item) },
                        onIgnore: {
                            leftovers.removeAll { $0.id == item.id }
                            selectedLeftoverIDs.remove(item.id)
                        }
                    )
                }
                if filteredLeftovers.isEmpty {
                    emptyState
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 145)
        }
    }

    private func appRow(_ app: InstalledApp) -> some View {
        UninstallerReplicaAppRow(
            app: app,
            displayName: displayName(for: app),
            isSelected: selectedAppIDs.contains(app.id),
            onToggle: { toggleApp(app) },
            onShowDetails: { detailedApp = app }
        )
    }

    private var emptyState: some View {
        Text(localized("没有项目，一切正常。", "No items. Everything looks good."))
            .font(.system(size: 12))
            .foregroundColor(.white.opacity(0.36))
            .frame(maxWidth: .infinity)
            .padding(.top, 54)
    }

    private func appDetailPanel(_ app: InstalledApp) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    detailedApp = nil
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                        Text(localized("返回", "Back"))
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.68))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 19)
            .padding(.bottom, 8)

            AppDetailView(app: app) { includeApp, moveToTrash in
                Task { await removeSingleApp(app, includeApp: includeApp, moveToTrash: moveToTrash) }
            }
        }
    }

    private func orbButton(disabled: Bool) -> some View {
        Button {
            showRemoveConfirmation = true
        } label: {
            CleanMyMacActionOrb(
                title: actionTitle,
                gradient: LinearGradient(
                    colors: disabled
                        ? [Color.white.opacity(0.09), Color.white.opacity(0.035)]
                        : [Color(red: 0.58, green: 0.67, blue: 0.93), Color(red: 0.37, green: 0.25, blue: 0.65)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                glowColor: .cyan,
                ringColor: Color.white.opacity(0.40),
                disabled: disabled,
                isHovered: orbHovered
            )
        }
        .buttonStyle(UninstallerOrbButtonStyle())
        .disabled(disabled)
        .onHover { orbHovered = $0 }
    }

    private func replicaCheckBox(selected: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(selected ? Color.cyan.opacity(0.92) : Color.white.opacity(0.48), lineWidth: 1.35)
                .frame(width: 15, height: 15)
            if selected {
                Circle().fill(Color.cyan.opacity(0.92)).frame(width: 15, height: 15)
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(Color(red: 0.18, green: 0.28, blue: 0.42))
            }
        }
    }

    private var filteredApps: [InstalledApp] {
        let base: [InstalledApp]
        switch category {
        case .all: base = appScanner.apps
        case .suspicious: base = suspiciousApps
        case .selected: base = appScanner.apps.filter { selectedAppIDs.contains($0.id) }
        case .appStore: base = appScanner.apps.filter(\.isAppStore)
        case .otherStore: base = appScanner.apps.filter { !$0.isAppStore }
        case .vendor(let vendor): base = apps(forVendor: vendor)
        case .leftovers: base = []
        }
        return base
            .filter { searchText.isEmpty || displayName(for: $0).localizedCaseInsensitiveContains(searchText) }
            .sorted { displayName(for: $0).localizedCaseInsensitiveCompare(displayName(for: $1)) == .orderedAscending }
    }

    private var filteredLeftovers: [DeepCleanItem] {
        leftovers
            .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var suspiciousApps: [InstalledApp] {
        appScanner.apps.filter { ($0.bundleIdentifier ?? "").isEmpty }
    }

    private func vendorName(for app: InstalledApp) -> String {
        let bundleID = (app.bundleIdentifier ?? "").lowercased()
        if bundleID.contains("google") { return "Google" }
        if bundleID.contains("macpaw") { return "MacPaw" }
        if bundleID.contains("jetbrains") { return "JetBrains" }
        return "其他"
    }

    private func apps(forVendor vendor: String) -> [InstalledApp] {
        appScanner.apps.filter { vendorName(for: $0) == vendor }
    }

    private func displayName(for app: InstalledApp) -> String {
        let bundleID = (app.bundleIdentifier ?? "").lowercased()
        if bundleID.contains("xinwechat") || app.name.lowercased() == "wechat" { return localized("微信", "WeChat") }
        if bundleID.contains("wechatdevtools") || app.name.lowercased().contains("wechatwebdevtools") { return localized("微信开发者工具", "WeChat DevTools") }
        if bundleID == "com.google.chrome" || app.name == "Chrome" { return "Google Chrome" }
        if bundleID.contains("macpaw") && app.name.lowercased().contains("cleanmymac") { return "CleanMyMac X" }
        return app.name
    }

    private var categoryTitle: String {
        switch category {
        case .all: return localized("所有应用程序", "All Applications")
        case .leftovers: return localized("残留项", "Leftovers")
        case .suspicious: return localized("可疑项", "Suspicious")
        case .selected: return localized("已选中", "Selected")
        case .appStore: return "App Store"
        case .otherStore: return localized("其他", "Other")
        case .vendor(let vendor): return vendor
        }
    }

    private var categoryDescription: String {
        switch category {
        case .all: return localized("您 Mac 上安装的所有应用程序均显示在下方。", "All applications installed on your Mac are shown below.")
        case .leftovers: return localized("已卸载应用程序留下的关联文件。", "Related files left by previously removed applications.")
        case .suspicious: return localized("缺少有效应用标识且可能需要检查的项目。", "Items without a valid application identifier that may need review.")
        case .selected: return localized("您当前选择移入废纸篓的所有项目。", "Everything currently selected for removal.")
        case .appStore: return localized("从 Mac App Store 安装的应用程序。", "Applications installed from the Mac App Store.")
        case .otherStore: return localized("从其他来源安装的应用程序。", "Applications installed from other sources.")
        case .vendor(let vendor): return localized("由 \(vendor) 发布的应用程序。", "Applications published by \(vendor).")
        }
    }

    private var currentSelectionCount: Int {
        category == .leftovers ? selectedLeftoverIDs.count : selectedAppIDs.count
    }

    private var selectionSummary: String {
        if category == .leftovers {
            let size = leftovers.filter { selectedLeftoverIDs.contains($0.id) }.reduce(0) { $0 + $1.size }
            return "\(selectedLeftoverIDs.count) \(localized("个项目", "items")) · \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))"
        }
        let apps = appScanner.apps.filter { selectedAppIDs.contains($0.id) }
        let size = apps.reduce(Int64(0)) { $0 + $1.size + $1.totalResidualSize }
        return "\(apps.count) \(localized("个应用程序", "apps")) · \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))"
    }

    private var actionTitle: String {
        category == .leftovers ? localized("移除", "Remove") : localized("卸载", "Uninstall")
    }

    private var confirmationMessage: String {
        if category == .leftovers {
            return localized("选中的残留文件将移入废纸篓，并保留恢复记录。", "Selected leftovers will be moved to Trash with recovery records.")
        }
        return localized("选中的应用程序及其关联文件将移入废纸篓；失败的项目会保留在列表中。", "Selected apps and related files will be moved to Trash; failed items remain listed.")
    }

    private func toggleApp(_ app: InstalledApp) {
        if selectedAppIDs.contains(app.id) { selectedAppIDs.remove(app.id) }
        else { selectedAppIDs.insert(app.id) }
    }

    private func toggleLeftover(_ item: DeepCleanItem) {
        if selectedLeftoverIDs.contains(item.id) { selectedLeftoverIDs.remove(item.id) }
        else { selectedLeftoverIDs.insert(item.id) }
    }

    @MainActor
    private func loadApplicationsAndRelatedFilesIfNeeded() async {
        if appScanner.apps.isEmpty {
            await appScanner.scanApplications()
        }
        guard !isLoadingRelatedFiles else { return }
        isLoadingRelatedFiles = true

        Task.detached(priority: .utility) {
            let scanner = DeepCleanScanner()
            let rawLeftovers = await scanner.scanUninstallerResiduals()

            await MainActor.run {
                for app in self.appScanner.apps where app.residualFiles.isEmpty {
                    Task {
                        await self.appScanner.scanResidualFiles(for: app)
                    }
                }
                let filteredLeftovers = rawLeftovers
                    .filter(self.isTrueLeftover)
                    .filter { ScanResultIgnoreStore.shouldInclude($0.url) }
                self.leftovers = filteredLeftovers
                self.selectedLeftoverIDs.subtract(filteredLeftovers.map(\.id))
                self.isLoadingRelatedFiles = false
            }
        }
    }

    private func isTrueLeftover(_ item: DeepCleanItem) -> Bool {
        let normalizedName = normalized(item.name)
        if normalizedName == "cef" { return false }

        for app in appScanner.apps {
            let candidates = [app.name, displayName(for: app), app.bundleIdentifier ?? ""]
            if candidates.map(normalized).contains(where: { !$0.isEmpty && ($0 == normalizedName || normalizedName.contains($0)) }) {
                return false
            }
        }

        let bundleIDs = appScanner.apps.compactMap(\.bundleIdentifier).map { $0.lowercased() }
        if normalizedName.contains("premiumsoft") && bundleIDs.contains(where: { $0.contains("navicat") }) { return false }
        if normalizedName.contains("wps") && bundleIDs.contains(where: { $0.contains("wps") || $0.contains("kingsoft") }) { return false }
        return true
    }

    private func normalized(_ value: String) -> String {
        value.lowercased().unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }

    @MainActor
    private func removeSelection() async {
        isRemoving = true
        if category == .leftovers {
            let targets = leftovers.filter { selectedLeftoverIDs.contains($0.id) }
            var success = 0
            var failed = 0
            for item in targets {
                if DeletionLogService.shared.logAndDelete(at: item.url, category: "UninstallerLeftovers") { success += 1 }
                else { failed += 1 }
            }
            leftovers.removeAll { selectedLeftoverIDs.contains($0.id) && !FileManager.default.fileExists(atPath: $0.url.path) }
            selectedLeftoverIDs = selectedLeftoverIDs.filter { id in leftovers.contains(where: { $0.id == id }) }
            resultMessage = localized("已移除 \(success) 个项目\(failed > 0 ? "，\(failed) 个失败并已保留" : "")。", "Removed \(success) items\(failed > 0 ? "; \(failed) failed and remain listed" : "").")
        } else {
            let targets = appScanner.apps.filter { selectedAppIDs.contains($0.id) }
            var success = 0
            var failed = 0
            for app in targets {
                await appScanner.scanResidualFiles(for: app)
                let result = await fileRemover.removeApp(app, includeApp: true, moveToTrash: true)
                if result.failedCount == 0 {
                    success += 1
                    selectedAppIDs.remove(app.id)
                    await appScanner.removeFromList(app: app)
                } else {
                    failed += 1
                }
            }
            resultMessage = localized("已卸载 \(success) 个应用程序\(failed > 0 ? "，\(failed) 个失败并已保留" : "")。", "Uninstalled \(success) apps\(failed > 0 ? "; \(failed) failed and remain listed" : "").")
        }
        isRemoving = false
        showResult = true
    }

    @MainActor
    private func removeSingleApp(_ app: InstalledApp, includeApp: Bool, moveToTrash: Bool) async {
        isRemoving = true
        if app.residualFiles.isEmpty { await appScanner.scanResidualFiles(for: app) }
        let result = await fileRemover.removeApp(app, includeApp: includeApp, moveToTrash: moveToTrash)
        if result.failedCount == 0 && includeApp {
            await appScanner.removeFromList(app: app)
            selectedAppIDs.remove(app.id)
            detailedApp = nil
        }
        resultMessage = result.failedCount == 0
            ? localized("操作成功完成。", "Operation completed successfully.")
            : localized("有 \(result.failedCount) 个项目失败并已保留。", "\(result.failedCount) items failed and remain listed.")
        isRemoving = false
        showResult = true
    }

    private func localized(_ chinese: String, _ english: String) -> String {
        loc.text(chinese, english)
    }
}

private struct UninstallerCategoryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.76 : 1)
            .scaleEffect(configuration.isPressed ? 0.994 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

private struct UninstallerReplicaAppRow: View {
    @ObservedObject var app: InstalledApp
    let displayName: String
    let isSelected: Bool
    let onToggle: () -> Void
    let onShowDetails: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.cyan.opacity(0.92) : Color.white.opacity(0.48), lineWidth: 1.35)
                        .frame(width: 15, height: 15)
                    if isSelected {
                        Circle()
                            .fill(Color.cyan.opacity(0.92))
                            .frame(width: 15, height: 15)
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(Color(red: 0.18, green: 0.28, blue: 0.42))
                    }
                }
            }
            .buttonStyle(.plain)

            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)

            Text(displayName)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(.white.opacity(0.88))
                .lineLimit(1)

            Spacer()

            Button(action: onShowDetails) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.72))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(ByteCountFormatter.string(fromByteCount: app.size + app.totalResidualSize, countStyle: .file))
                .font(.system(size: 10.5))
                .foregroundColor(.white.opacity(0.60))
                .frame(width: 68, alignment: .trailing)
        }
        .frame(height: 45)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }
}

private struct UninstallerRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private struct UninstallerOrbButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

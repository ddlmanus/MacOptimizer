import SwiftUI

// MARK: - 语言枚举
enum AppLanguage: String, CaseIterable {
    case chinese = "zh"
    case english = "en"
    
    var displayName: String {
        switch self {
        case .chinese: return "中文"
        case .english: return "English"
        }
    }
    
    var flag: String {
        switch self {
        case .chinese: return "🇨🇳"
        case .english: return "🇺🇸"
        }
    }
}

// MARK: - 本地化管理器
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @AppStorage("app_language") private var languageCode: String = "zh"
    
    @Published var currentLanguage: AppLanguage = .chinese
    
    init() {
        currentLanguage = AppLanguage(rawValue: languageCode) ?? .chinese
    }
    
    func setLanguage(_ language: AppLanguage) {
        languageCode = language.rawValue
        currentLanguage = language
        objectWillChange.send()
    }
    
    func toggleLanguage() {
        let newLanguage: AppLanguage = currentLanguage == .chinese ? .english : .chinese
        setLanguage(newLanguage)
    }
    
    // MARK: - 翻译函数
    func L(_ key: String) -> String {
        return translations[key]?[currentLanguage] ?? key
    }
    
    // MARK: - 翻译字典
    private let translations: [String: [AppLanguage: String]] = [
        // 侧边栏菜单
        "monitor": [.chinese: "控制台", .english: "Console"],
        "uninstaller": [.chinese: "应用卸载", .english: "Uninstaller"],
        "deepClean": [.chinese: "深度清理", .english: "Deep Clean"],
        "cleaner": [.chinese: "垃圾清理", .english: "Cleaner"],
        "optimizer": [.chinese: "系统优化", .english: "Optimizer"],
        "largeFiles": [.chinese: "大文件查找", .english: "Large Files"],
        "fileExplorer": [.chinese: "文件管理", .english: "File Explorer"],
        "trash": [.chinese: "废纸篓", .english: "Trash"],
        
        // 模块描述
        "monitor_desc": [.chinese: "CPU、内存、网络端口实时监控", .english: "Real-time CPU, Memory, Network monitoring"],
        "uninstaller_desc": [.chinese: "完全删除应用及其残留文件", .english: "Completely remove apps and residual files"],
        "deepClean_desc": [.chinese: "扫描已卸载应用的残留文件", .english: "Scan orphaned files from uninstalled apps"],
        "cleaner_desc": [.chinese: "清理缓存和系统垃圾", .english: "Clean cache and system junk"],
        "optimizer_desc": [.chinese: "管理启动项，释放内存", .english: "Manage startup items, free memory"],
        "largeFiles_desc": [.chinese: "发现并清理占用空间的大文件", .english: "Find and clean large files"],
        "fileExplorer_desc": [.chinese: "浏览和管理磁盘文件", .english: "Browse and manage disk files"],
        "trash_desc": [.chinese: "查看并清空废纸篓", .english: "View and empty trash"],
        
        // 通用
        "loading": [.chinese: "加载中...", .english: "Loading..."],
        "scanning": [.chinese: "扫描中...", .english: "Scanning..."],
        "scan": [.chinese: "扫描", .english: "Scan"],
        "clean": [.chinese: "清理", .english: "Clean"],
        "delete": [.chinese: "删除", .english: "Delete"],
        "cancel": [.chinese: "取消", .english: "Cancel"],
        "confirm": [.chinese: "确定", .english: "Confirm"],
        "create": [.chinese: "创建", .english: "Create"],
        "rename": [.chinese: "重命名", .english: "Rename"],
        "open": [.chinese: "打开", .english: "Open"],
        "refresh": [.chinese: "刷新", .english: "Refresh"],
        "selectAll": [.chinese: "全选", .english: "Select All"],
        "deselectAll": [.chinese: "取消全选", .english: "Deselect All"],
        "selected": [.chinese: "已选择", .english: "Selected"],
        "total": [.chinese: "共计", .english: "Total"],
        "items": [.chinese: "项", .english: "items"],
        "size": [.chinese: "大小", .english: "Size"],
        "name": [.chinese: "名称", .english: "Name"],
        "date": [.chinese: "日期", .english: "Date"],
        "type": [.chinese: "类型", .english: "Type"],
        "path": [.chinese: "路径", .english: "Path"],
        
        // 控制台
        "cpu_usage": [.chinese: "CPU 使用率", .english: "CPU Usage"],
        "memory_usage": [.chinese: "内存使用", .english: "Memory Usage"],
        "disk_usage": [.chinese: "磁盘使用", .english: "Disk Usage"],
        "used": [.chinese: "已用", .english: "Used"],
        "free": [.chinese: "可用", .english: "Free"],
        "processes": [.chinese: "进程", .english: "Processes"],
        "ports": [.chinese: "端口", .english: "Ports"],
        "stop_process": [.chinese: "停止进程", .english: "Stop Process"],
        "release_port": [.chinese: "释放端口", .english: "Release Port"],
        
        // 应用卸载
        "installed_apps": [.chinese: "已安装应用", .english: "Installed Apps"],
        "search_apps": [.chinese: "搜索应用...", .english: "Search apps..."],
        "residual_files": [.chinese: "残留文件", .english: "Residual Files"],
        "uninstall": [.chinese: "卸载", .english: "Uninstall"],
        "move_to_trash": [.chinese: "移至废纸篓", .english: "Move to Trash"],
        "permanently_delete": [.chinese: "永久删除", .english: "Permanently Delete"],
        
        // 深度清理
        "deep_clean": [.chinese: "深度清理", .english: "Deep Clean"],
        "orphaned_files": [.chinese: "孤立文件", .english: "Orphaned Files"],
        "system_clean": [.chinese: "系统很干净", .english: "System is Clean"],
        "no_orphaned_files": [.chinese: "未发现已卸载应用的残留文件", .english: "No orphaned files from uninstalled apps"],
        "app_support": [.chinese: "应用支持", .english: "App Support"],
        "cache": [.chinese: "缓存", .english: "Cache"],
        "preferences": [.chinese: "偏好设置", .english: "Preferences"],
        "containers": [.chinese: "容器", .english: "Containers"],
        "saved_state": [.chinese: "保存状态", .english: "Saved State"],
        "logs": [.chinese: "日志", .english: "Logs"],
        "group_containers": [.chinese: "群组容器", .english: "Group Containers"],
        "cookies": [.chinese: "Cookies", .english: "Cookies"],
        "launch_agents": [.chinese: "启动代理", .english: "Launch Agents"],
        "crash_reports": [.chinese: "崩溃报告", .english: "Crash Reports"],
        
        // 垃圾清理
        "junk_files": [.chinese: "垃圾文件", .english: "Junk Files"],
        "system_cache": [.chinese: "系统缓存", .english: "System Cache"],
        "app_cache": [.chinese: "应用缓存", .english: "App Cache"],
        "browser_cache": [.chinese: "浏览器缓存", .english: "Browser Cache"],
        "log_files": [.chinese: "日志文件", .english: "Log Files"],
        
        // 系统优化
        "startup_items": [.chinese: "启动项", .english: "Startup Items"],
        "free_memory": [.chinese: "释放内存", .english: "Free Memory"],
        "optimize": [.chinese: "优化", .english: "Optimize"],
        
        // 大文件
        "large_files": [.chinese: "大文件", .english: "Large Files"],
        "min_size": [.chinese: "最小大小", .english: "Min Size"],
        "scan_directory": [.chinese: "扫描目录", .english: "Scan Directory"],
        
        // 文件管理器
        "quick_access": [.chinese: "快捷访问", .english: "Quick Access"],
        "home": [.chinese: "主目录", .english: "Home"],
        "desktop": [.chinese: "桌面", .english: "Desktop"],
        "documents": [.chinese: "文稿", .english: "Documents"],
        "downloads": [.chinese: "下载", .english: "Downloads"],
        "applications": [.chinese: "应用程序", .english: "Applications"],
        "disk_root": [.chinese: "磁盘根目录", .english: "Disk Root"],
        "show_hidden": [.chinese: "显示隐藏文件", .english: "Show Hidden Files"],
        "new_folder": [.chinese: "新建文件夹", .english: "New Folder"],
        "new_file": [.chinese: "新建文件", .english: "New File"],
        "open_in_terminal": [.chinese: "在终端中打开", .english: "Open in Terminal"],
        "enter_directory": [.chinese: "进入目录", .english: "Enter Directory"],
        "show_in_finder": [.chinese: "在 Finder 中显示", .english: "Show in Finder"],
        "input_path": [.chinese: "输入路径...", .english: "Enter path..."],
        "go": [.chinese: "跳转", .english: "Go"],
        "go_back": [.chinese: "返回上级目录", .english: "Go to Parent"],
        "path_not_exist": [.chinese: "路径不存在或不是目录", .english: "Path does not exist or is not a directory"],
        "cannot_access": [.chinese: "无法访问此目录", .english: "Cannot access this directory"],
        "folder_name": [.chinese: "文件夹名称", .english: "Folder Name"],
        "file_name": [.chinese: "文件名称", .english: "File Name"],
        "new_name": [.chinese: "新名称", .english: "New Name"],
        
        // 废纸篓
        "trash_empty": [.chinese: "废纸篓为空", .english: "Trash is Empty"],
        "empty_trash": [.chinese: "清空废纸篓", .english: "Empty Trash"],
        
        // 确认对话框
        "confirm_delete": [.chinese: "确认删除", .english: "Confirm Delete"],
        "confirm_delete_msg": [.chinese: "确定要删除吗？", .english: "Are you sure you want to delete?"],
        "confirm_clean": [.chinese: "确认清理", .english: "Confirm Clean"],
        "clean_complete": [.chinese: "清理完成", .english: "Clean Complete"],
        "cleaned_files": [.chinese: "已清理", .english: "Cleaned"],
        "freed_space": [.chinese: "释放空间", .english: "Freed Space"],
        
        // 语言
        "language": [.chinese: "语言", .english: "Language"],
        "switch_language": [.chinese: "切换语言", .english: "Switch Language"],
    ]
}

// MARK: - 全局本地化函数
func L(_ key: String) -> String {
    return LocalizationManager.shared.L(key)
}

// MARK: - 环境键
struct LocalizationKey: EnvironmentKey {
    static let defaultValue = LocalizationManager.shared
}

extension EnvironmentValues {
    var localization: LocalizationManager {
        get { self[LocalizationKey.self] }
        set { self[LocalizationKey.self] = newValue }
    }
}

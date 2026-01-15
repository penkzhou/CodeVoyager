import Foundation
import AppKit
import Combine
import os.log

/// 主题管理器
///
/// 管理语法高亮主题的切换、持久化和系统外观监听。
///
/// ## 设计决策
/// - 手动选择优先：用户明确选择主题后，不受系统外观影响
/// - 持久化偏好：使用 UserDefaults 保存用户的主题选择
/// - 系统外观监听：通过 DistributedNotificationCenter 监听外观变化
/// - 线程安全：通过 @MainActor 保证在主线程访问
///
/// ## 使用示例
/// ```swift
/// // 推荐：通过依赖注入使用
/// let manager: ThemeManagerProtocol = ThemeManager.shared
///
/// // 订阅主题变化
/// manager.themeDidChange
///     .sink { theme in
///         updateUI(with: theme)
///     }
///     .store(in: &cancellables)
///
/// // 手动切换主题
/// manager.setTheme(withId: "dark")
///
/// // 恢复跟随系统
/// manager.setFollowSystem()
/// ```
@MainActor
public final class ThemeManager: ThemeManagerProtocol {
    /// 共享实例
    public static let shared = ThemeManager()

    private let logger = Logger(subsystem: "CodeVoyager", category: "ThemeManager")

    /// 内部存储的当前主题
    private var _currentTheme: SyntaxTheme

    /// 内部存储的偏好
    private var _preference: ThemePreference

    /// 主题变更通知的主题
    private let themeChangeSubject = PassthroughSubject<SyntaxTheme, Never>()

    /// 系统外观变化监听器
    private var appearanceObserver: Any?

    // MARK: - UserDefaults Keys

    private enum DefaultsKeys {
        static let preference = "CodeVoyager.ThemeManager.preference"
    }

    // MARK: - ThemeManagerProtocol

    public var currentTheme: SyntaxTheme {
        _currentTheme
    }

    public var preference: ThemePreference {
        _preference
    }

    public var availableThemes: [SyntaxTheme] {
        DefaultThemes.all
    }

    public var themeDidChange: AnyPublisher<SyntaxTheme, Never> {
        themeChangeSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    public init() {
        // 加载保存的偏好或使用默认值
        let savedPreference = Self.loadPreference()
        self._preference = savedPreference

        // 根据偏好确定初始主题
        switch savedPreference {
        case .followSystem:
            self._currentTheme = Self.themeForCurrentSystemAppearance()
        case .manual(let themeId):
            if let theme = DefaultThemes.theme(withId: themeId) {
                self._currentTheme = theme
            } else {
                // 降级：用户保存的主题找不到，回退到 light 主题
                logger.warning("Saved theme '\(themeId)' not found, falling back to light theme")
                self._currentTheme = DefaultThemes.light
            }
        }

        // 设置系统外观监听
        setupAppearanceObserver()

        logger.debug("ThemeManager initialized with preference: \(String(describing: savedPreference))")
    }

    deinit {
        if let observer = appearanceObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    // MARK: - Theme Setting

    public func setTheme(_ theme: SyntaxTheme) {
        let oldTheme = _currentTheme
        _currentTheme = theme
        _preference = .manual(themeId: theme.id)

        // 持久化偏好
        savePreference(.manual(themeId: theme.id))

        // 发送通知（如果主题确实变化了）
        if oldTheme.id != theme.id {
            logger.info("Theme changed to: \(theme.name)")
            themeChangeSubject.send(theme)
        }
    }

    @discardableResult
    public func setTheme(withId themeId: String) -> Bool {
        guard let theme = DefaultThemes.theme(withId: themeId) else {
            logger.warning("Theme not found: \(themeId)")
            return false
        }
        setTheme(theme)
        return true
    }

    public func setFollowSystem() {
        let newTheme = Self.themeForCurrentSystemAppearance()
        let oldTheme = _currentTheme
        _currentTheme = newTheme
        _preference = .followSystem

        // 持久化偏好
        savePreference(.followSystem)

        // 发送通知（如果主题确实变化了）
        if oldTheme.id != newTheme.id {
            logger.info("Follow system: theme changed to \(newTheme.name)")
            themeChangeSubject.send(newTheme)
        } else {
            logger.debug("Follow system enabled, theme unchanged: \(newTheme.name)")
        }
    }

    public func updateForSystemAppearance() {
        // 仅在跟随系统时响应
        guard case .followSystem = _preference else {
            return
        }

        let newTheme = Self.themeForCurrentSystemAppearance()
        let oldTheme = _currentTheme
        _currentTheme = newTheme

        // 发送通知（如果主题确实变化了）
        if oldTheme.id != newTheme.id {
            logger.info("System appearance changed: theme updated to \(newTheme.name)")
            themeChangeSubject.send(newTheme)
        }
    }

    // MARK: - Private Methods

    /// 设置系统外观变化监听
    private func setupAppearanceObserver() {
        // 监听系统外观变化通知
        appearanceObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateForSystemAppearance()
            }
        }
    }

    /// 根据当前系统外观获取对应主题
    ///
    /// - Note: 如果 NSApp 不可用（如测试环境），默认返回 light 主题
    private static func themeForCurrentSystemAppearance() -> SyntaxTheme {
        guard let app = NSApp else {
            // 测试环境或 App 未初始化时，默认使用 light 主题
            Logger(subsystem: "CodeVoyager", category: "ThemeManager")
                .debug("NSApp not available (likely test environment), defaulting to light theme")
            return DefaultThemes.light
        }

        let appearance = app.effectiveAppearance
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        return isDark ? DefaultThemes.dark : DefaultThemes.light
    }

    // MARK: - Persistence

    /// 保存偏好到 UserDefaults
    private func savePreference(_ preference: ThemePreference) {
        do {
            let data = try JSONEncoder().encode(preference)
            UserDefaults.standard.set(data, forKey: DefaultsKeys.preference)
            logger.debug("Preference saved: \(String(describing: preference))")
        } catch {
            logger.error("Failed to save preference: \(error.localizedDescription)")
        }
    }

    /// 从 UserDefaults 加载偏好
    private nonisolated static func loadPreference() -> ThemePreference {
        guard let data = UserDefaults.standard.data(forKey: DefaultsKeys.preference) else {
            return .followSystem
        }

        do {
            return try JSONDecoder().decode(ThemePreference.self, from: data)
        } catch {
            Logger(subsystem: "CodeVoyager", category: "ThemeManager")
                .warning("Failed to load preference, using default: \(error.localizedDescription)")
            return .followSystem
        }
    }
}

// MARK: - Testing Support

#if DEBUG
public extension ThemeManager {
    /// 重置为默认状态
    ///
    /// - Warning: 仅用于测试场景，此方法仅在 DEBUG 构建中可用。
    ///   生产代码不应依赖此方法。
    func reset() {
        _preference = .followSystem
        _currentTheme = Self.themeForCurrentSystemAppearance()

        // 清除保存的偏好
        UserDefaults.standard.removeObject(forKey: DefaultsKeys.preference)

        logger.debug("ThemeManager reset to default state")
    }
}
#endif

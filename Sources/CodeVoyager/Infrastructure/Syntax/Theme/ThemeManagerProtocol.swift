import Foundation
import Combine

/// 主题偏好选择
///
/// 定义用户的主题选择偏好。
public enum ThemePreference: Sendable, Equatable, Codable {
    /// 跟随系统外观自动切换
    case followSystem

    /// 手动选择特定主题
    case manual(themeId: String)

    /// 获取偏好中指定的主题 ID（如果有）
    public var themeId: String? {
        switch self {
        case .followSystem:
            return nil
        case .manual(let id):
            return id
        }
    }

    /// 是否跟随系统外观
    public var isFollowingSystem: Bool {
        self == .followSystem
    }
}

/// 主题管理协议
///
/// 定义主题管理的核心接口，支持依赖注入以便测试时 mock。
///
/// ## 职责
/// - 管理当前激活的主题
/// - 处理主题切换（手动选择或跟随系统）
/// - 提供所有可用主题列表
/// - 持久化用户主题偏好
///
/// ## 主题切换规则
/// 1. 默认跟随系统外观自动切换浅色/深色主题
/// 2. 用户手动选择特定主题后，完全忽略系统外观变化
/// 3. 用户需手动选择「跟随系统」才恢复自动切换
///
/// ## 测试 Mock 示例
/// ```swift
/// @MainActor
/// final class MockThemeManager: ThemeManagerProtocol {
///     var currentTheme: SyntaxTheme = DefaultThemes.light
///     var preference: ThemePreference = .followSystem
///     var availableThemes: [SyntaxTheme] = DefaultThemes.all
///
///     private let themeSubject = PassthroughSubject<SyntaxTheme, Never>()
///     var themeDidChange: AnyPublisher<SyntaxTheme, Never> {
///         themeSubject.eraseToAnyPublisher()
///     }
///
///     func setTheme(_ theme: SyntaxTheme) {
///         currentTheme = theme
///         preference = .manual(themeId: theme.id)
///         themeSubject.send(theme)
///     }
///
///     @discardableResult
///     func setTheme(withId themeId: String) -> Bool {
///         guard let theme = availableThemes.first(where: { $0.id == themeId }) else {
///             return false
///         }
///         setTheme(theme)
///         return true
///     }
///
///     func setFollowSystem() {
///         preference = .followSystem
///     }
///
///     func updateForSystemAppearance() {
///         // 测试时可根据需要实现
///     }
/// }
/// ```
@MainActor
public protocol ThemeManagerProtocol: AnyObject {
    /// 当前激活的主题
    var currentTheme: SyntaxTheme { get }

    /// 当前主题偏好
    var preference: ThemePreference { get }

    /// 所有可用主题
    var availableThemes: [SyntaxTheme] { get }

    /// 主题变更通知发布者
    ///
    /// 当主题发生变化时发送新主题。订阅者可用于更新 UI。
    var themeDidChange: AnyPublisher<SyntaxTheme, Never> { get }

    /// 设置为指定主题（手动选择）
    ///
    /// 调用此方法后，主题将不再跟随系统外观变化，
    /// 直到调用 `setFollowSystem()` 恢复。
    ///
    /// - Parameter theme: 目标主题
    func setTheme(_ theme: SyntaxTheme)

    /// 根据主题 ID 设置主题
    ///
    /// - Parameter themeId: 主题 ID
    /// - Returns: 是否设置成功（ID 不存在时返回 false）
    @discardableResult
    func setTheme(withId themeId: String) -> Bool

    /// 恢复跟随系统外观
    ///
    /// 调用此方法后，主题将根据系统外观自动切换。
    func setFollowSystem()

    /// 根据系统外观更新主题
    ///
    /// 仅在 `preference == .followSystem` 时生效。
    /// 通常由系统外观变化通知触发。
    func updateForSystemAppearance()
}

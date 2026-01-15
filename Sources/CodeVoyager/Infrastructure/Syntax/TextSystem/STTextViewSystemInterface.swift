import AppKit
import STTextView
import Neon
import os.log

/// STTextView 的 TextSystemInterface 适配器
///
/// 用于连接 Neon 高亮系统与 STTextView (TextKit 2)。
/// 实现 Neon 的 `TextSystemInterface` 协议，将 Token 样式应用到 STTextView。
///
/// ## 使用示例
/// ```swift
/// let attributeProvider: STTextViewSystemInterface.AttributeProvider = { token in
///     let theme = ThemeManager.shared.currentTheme
///     return theme.attributes(for: token.name, baseFont: .monospacedSystemFont(ofSize: 13, weight: .regular))
/// }
///
/// let interface = STTextViewSystemInterface(
///     textView: textView,
///     attributeProvider: attributeProvider
/// )
///
/// let highlighter = Highlighter(
///     textInterface: interface,
///     tokenProvider: myTokenProvider
/// )
/// ```
///
/// ## 性能说明
/// - 使用 `updateLayout: false` 避免每个 Token 触发重排
/// - 调用者应在批量高亮完成后手动触发 `textView.needsLayout = true`
public struct STTextViewSystemInterface {
    private static let logger = Logger(subsystem: "CodeVoyager", category: "STTextViewSystemInterface")

    /// 属性提供者类型
    /// 接收 Token，返回对应的属性字典；返回 nil 表示忽略该 Token
    public typealias AttributeProvider = (Token) -> [NSAttributedString.Key: Any]?

    /// 被适配的 STTextView 实例
    public let textView: STTextView

    /// 属性提供者，将 Token 转换为 NSAttributedString 属性
    public let attributeProvider: AttributeProvider

    // MARK: - Initialization

    /// 创建 STTextView 适配器
    /// - Parameters:
    ///   - textView: 需要应用语法高亮的 STTextView
    ///   - attributeProvider: 属性提供者，将 Token 转换为文本属性
    public init(
        textView: STTextView,
        attributeProvider: @escaping AttributeProvider
    ) {
        self.textView = textView
        self.attributeProvider = attributeProvider
    }
}

// MARK: - TextSystemInterface

extension STTextViewSystemInterface: TextSystemInterface {
    /// 清除指定范围内的样式
    ///
    /// 将范围内的文本样式重置为空属性（保留字体和颜色由基础样式决定）
    /// - Parameter range: 需要清除样式的字符范围
    public func clearStyle(in range: NSRange) {
        setAttributes([:], in: range)
    }

    /// 对单个 Token 应用样式
    ///
    /// 使用 attributeProvider 获取 Token 对应的属性，然后应用到文本
    /// - Parameter token: 包含样式位置和名称的 Token
    public func applyStyle(to token: Token) {
        guard let attrs = attributeProvider(token) else {
            return
        }
        setAttributes(attrs, in: token.range)
    }

    /// 文本视图中的总字符数
    public var length: Int {
        textView.textContentManager.length
    }

    /// 当前可见范围（视口中显示的文本范围）
    ///
    /// 用于优化高亮性能，Highlighter 只处理可见范围和周边缓冲区
    public var visibleRange: NSRange {
        guard let viewportRange = textView.textLayoutManager.textViewportLayoutController.viewportRange else {
            // 如果无法获取可见范围，返回全文范围
            return NSRange(location: 0, length: length)
        }

        return NSRange(viewportRange, in: textView.textContentManager)
    }
}

// MARK: - Private Helpers

private extension STTextViewSystemInterface {
    /// 应用属性到指定范围
    ///
    /// - Parameters:
    ///   - attrs: 要应用的属性字典
    ///   - range: 目标范围
    ///
    /// - Note: 使用 `updateLayout: false` 避免过度重排，
    ///   调用者应在完成所有高亮后统一触发布局更新
    func setAttributes(_ attrs: [NSAttributedString.Key: Any], in range: NSRange) {
        // 边界检查
        let textLength = length
        guard range.location >= 0,
              range.location < textLength else {
            Self.logger.debug("Skipping setAttributes: range \(range) starts beyond text length \(textLength)")
            return
        }

        // 钳制范围以避免越界
        let endLocation = min(range.upperBound, textLength)
        let clampedRange = NSRange(location: range.location, length: endLocation - range.location)

        guard clampedRange.length > 0 else {
            return
        }

        // 将 NSRange 转换为 NSTextRange
        guard let textRange = NSTextRange(clampedRange, in: textView.textContentManager) else {
            Self.logger.debug("Failed to create NSTextRange from NSRange \(clampedRange)")
            return
        }

        // 使用 TextKit 2 的 renderingAttributes API
        // 这是临时样式，不会永久修改 textStorage
        textView.textLayoutManager.setRenderingAttributes(attrs, for: textRange)
    }
}

// MARK: - NSTextContentManager Length Extension

extension NSTextContentManager {
    /// 文本内容的总长度
    var length: Int {
        guard let textStorage = (self as? NSTextContentStorage)?.textStorage else {
            // 降级：遍历计算长度
            var totalLength = 0
            enumerateTextElements(from: documentRange.location) { element in
                if let textParagraph = element as? NSTextParagraph {
                    totalLength += textParagraph.attributedString.length
                }
                return true
            }
            return totalLength
        }
        return textStorage.length
    }
}

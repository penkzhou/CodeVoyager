import Foundation
import AppKit
import os.log

/// Token 样式定义
///
/// 用于定义语法高亮中单个 Token 的视觉样式，包括颜色和字体修饰。
///
/// ## 使用示例
/// ```swift
/// let keywordStyle = TokenStyle(color: .systemBlue, isBold: true)
/// let commentStyle = TokenStyle(color: .systemGray, isItalic: true)
/// ```
public struct TokenStyle: Sendable, Equatable, Hashable {
    /// 用于记录字体创建失败的 Logger（静态实例避免重复创建）
    private static let logger = Logger(subsystem: "CodeVoyager", category: "TokenStyle")
    /// Token 的前景色
    public let color: NSColor

    /// 是否使用粗体
    public let isBold: Bool

    /// 是否使用斜体
    public let isItalic: Bool

    // MARK: - Initialization

    /// 创建 Token 样式
    /// - Parameters:
    ///   - color: 前景色
    ///   - isBold: 是否粗体，默认 false
    ///   - isItalic: 是否斜体，默认 false
    public init(color: NSColor, isBold: Bool = false, isItalic: Bool = false) {
        self.color = color
        self.isBold = isBold
        self.isItalic = isItalic
    }

    // MARK: - Font Generation

    /// 生成应用了样式的字体
    /// - Parameter baseFont: 基础字体
    /// - Returns: 应用粗体/斜体后的字体
    ///
    /// - Note: 如果字体创建失败（例如字体不支持请求的 traits），将静默回退到基础字体并记录警告日志
    public func font(from baseFont: NSFont) -> NSFont {
        var font = baseFont

        if isBold || isItalic {
            var traits: NSFontDescriptor.SymbolicTraits = []

            if isBold {
                traits.insert(.bold)
            }
            if isItalic {
                traits.insert(.italic)
            }

            let descriptor = font.fontDescriptor.withSymbolicTraits(traits)
            if let styledFont = NSFont(descriptor: descriptor, size: font.pointSize) {
                font = styledFont
            } else {
                // 降级：字体创建失败，使用基础字体
                Self.logger.warning("Failed to create font with traits (bold: \(self.isBold), italic: \(self.isItalic)) for font '\(baseFont.fontName)', falling back to base font")
            }
        }

        return font
    }

    /// 生成 NSAttributedString 属性字典
    /// - Parameter baseFont: 基础字体
    /// - Returns: 可直接用于 NSAttributedString 的属性字典
    public func attributes(baseFont: NSFont) -> [NSAttributedString.Key: Any] {
        [
            .foregroundColor: color,
            .font: font(from: baseFont)
        ]
    }
}

// MARK: - Convenience Initializers

public extension TokenStyle {
    /// 创建仅有颜色的样式
    /// - Parameter color: 前景色
    /// - Returns: 普通样式（非粗体、非斜体）
    static func plain(_ color: NSColor) -> TokenStyle {
        TokenStyle(color: color)
    }

    /// 创建粗体样式
    /// - Parameter color: 前景色
    /// - Returns: 粗体样式
    static func bold(_ color: NSColor) -> TokenStyle {
        TokenStyle(color: color, isBold: true)
    }

    /// 创建斜体样式
    /// - Parameter color: 前景色
    /// - Returns: 斜体样式
    static func italic(_ color: NSColor) -> TokenStyle {
        TokenStyle(color: color, isItalic: true)
    }

    /// 创建粗斜体样式
    /// - Parameter color: 前景色
    /// - Returns: 粗斜体样式
    static func boldItalic(_ color: NSColor) -> TokenStyle {
        TokenStyle(color: color, isBold: true, isItalic: true)
    }
}

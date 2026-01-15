import Foundation
import AppKit

/// 内置主题定义
///
/// 提供默认的浅色和深色主题，配色参考 VSCode Default 风格。
/// 这些主题可作为 ThemeManager 的默认选项。
public enum DefaultThemes {

    // MARK: - Light Theme

    /// 默认浅色主题
    ///
    /// 配色参考 VSCode Light+ 主题
    public static let light: SyntaxTheme = {
        // 颜色定义
        let background = NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)          // #FFFFFF - 白色
        let lineNumber = NSColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0)          // #999999 - 灰色
        let currentLine = NSColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)      // #F2F2F2 - 浅灰色
        let selection = NSColor(red: 0.68, green: 0.84, blue: 1.0, alpha: 1.0)         // #ADD6FF - 浅蓝色
        let defaultText = NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)         // #000000 - 黑色

        // Token 颜色
        let keyword = NSColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)           // #0000FF - 蓝色
        let type = NSColor(red: 0.15, green: 0.53, blue: 0.53, alpha: 1.0)            // #267F7F - 青色
        let string = NSColor(red: 0.64, green: 0.08, blue: 0.08, alpha: 1.0)          // #A31515 - 深红色
        let number = NSColor(red: 0.0, green: 0.6, blue: 0.0, alpha: 1.0)             // #009900 - 绿色
        let comment = NSColor(red: 0.0, green: 0.5, blue: 0.0, alpha: 1.0)            // #008000 - 绿色
        let function = NSColor(red: 0.47, green: 0.31, blue: 0.09, alpha: 1.0)        // #795E26 - 棕色
        let variable = NSColor(red: 0.0, green: 0.25, blue: 0.5, alpha: 1.0)          // #001080 - 深蓝色
        let property = NSColor(red: 0.0, green: 0.25, blue: 0.5, alpha: 1.0)          // #001080 - 深蓝色
        let constant = NSColor(red: 0.0, green: 0.44, blue: 0.75, alpha: 1.0)         // #0070C1 - 蓝色
        let attribute = NSColor(red: 0.5, green: 0.5, blue: 0.0, alpha: 1.0)          // #808000 - 橄榄色
        let `operator` = NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)         // 黑色
        let punctuation = NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)        // 黑色

        // Markdown 特殊颜色
        let heading = NSColor(red: 0.0, green: 0.0, blue: 0.5, alpha: 1.0)            // #000080 - 深蓝色
        let link = NSColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0)               // 蓝色

        return SyntaxTheme(
            id: "light",
            name: "Light+",
            appearance: .light,
            backgroundColor: background,
            lineNumberColor: lineNumber,
            currentLineBackgroundColor: currentLine,
            selectionBackgroundColor: selection,
            defaultStyle: .plain(defaultText),
            tokenStyles: buildTokenStyles(
                keyword: keyword,
                type: type,
                string: string,
                number: number,
                comment: comment,
                function: function,
                variable: variable,
                property: property,
                constant: constant,
                attribute: attribute,
                operator: `operator`,
                punctuation: punctuation,
                heading: heading,
                link: link
            )
        )
    }()

    // MARK: - Dark Theme

    /// 默认深色主题
    ///
    /// 配色参考 VSCode Dark+ 主题
    public static let dark: SyntaxTheme = {
        // 颜色定义
        let background = NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)      // #1E1E1E
        let lineNumber = NSColor(red: 0.52, green: 0.52, blue: 0.52, alpha: 1.0)      // #858585
        let currentLine = NSColor(red: 0.16, green: 0.16, blue: 0.16, alpha: 1.0)     // #282828
        let selection = NSColor(red: 0.17, green: 0.34, blue: 0.52, alpha: 1.0)       // #264F78
        let defaultText = NSColor(red: 0.86, green: 0.86, blue: 0.86, alpha: 1.0)     // #D4D4D4

        // Token 颜色
        let keyword = NSColor(red: 0.34, green: 0.61, blue: 0.84, alpha: 1.0)         // #569CD6 - 蓝色
        let type = NSColor(red: 0.31, green: 0.79, blue: 0.76, alpha: 1.0)            // #4EC9B0 - 青色
        let string = NSColor(red: 0.81, green: 0.54, blue: 0.47, alpha: 1.0)          // #CE9178 - 橙色
        let number = NSColor(red: 0.71, green: 0.81, blue: 0.65, alpha: 1.0)          // #B5CEA8 - 浅绿色
        let comment = NSColor(red: 0.42, green: 0.56, blue: 0.34, alpha: 1.0)         // #6A9955 - 绿色
        let function = NSColor(red: 0.86, green: 0.86, blue: 0.67, alpha: 1.0)        // #DCDCAA - 黄色
        let variable = NSColor(red: 0.61, green: 0.86, blue: 1.0, alpha: 1.0)         // #9CDCFE - 浅蓝色
        let property = NSColor(red: 0.61, green: 0.86, blue: 1.0, alpha: 1.0)         // #9CDCFE - 浅蓝色
        let constant = NSColor(red: 0.31, green: 0.79, blue: 0.76, alpha: 1.0)        // #4EC9B0 - 青色
        let attribute = NSColor(red: 0.61, green: 0.86, blue: 1.0, alpha: 1.0)        // #9CDCFE - 浅蓝色
        let `operator` = NSColor(red: 0.86, green: 0.86, blue: 0.86, alpha: 1.0)      // #D4D4D4
        let punctuation = NSColor(red: 0.86, green: 0.86, blue: 0.86, alpha: 1.0)     // #D4D4D4

        // Markdown 特殊颜色
        let heading = NSColor(red: 0.34, green: 0.61, blue: 0.84, alpha: 1.0)         // #569CD6 - 蓝色
        let link = NSColor(red: 0.31, green: 0.79, blue: 0.76, alpha: 1.0)            // #4EC9B0 - 青色

        return SyntaxTheme(
            id: "dark",
            name: "Dark+",
            appearance: .dark,
            backgroundColor: background,
            lineNumberColor: lineNumber,
            currentLineBackgroundColor: currentLine,
            selectionBackgroundColor: selection,
            defaultStyle: .plain(defaultText),
            tokenStyles: buildTokenStyles(
                keyword: keyword,
                type: type,
                string: string,
                number: number,
                comment: comment,
                function: function,
                variable: variable,
                property: property,
                constant: constant,
                attribute: attribute,
                operator: `operator`,
                punctuation: punctuation,
                heading: heading,
                link: link
            )
        )
    }()

    // MARK: - All Themes

    /// 所有内置主题
    ///
    /// - Important: 新增内置主题时，必须将其添加到此数组中！
    ///   此数组被 `ThemeManager.availableThemes` 和 `theme(withId:)` 使用，
    ///   遗漏添加会导致新主题无法被用户选择。
    public static let all: [SyntaxTheme] = [light, dark]

    /// 根据 ID 获取主题
    /// - Parameter id: 主题 ID
    /// - Returns: 对应的主题，未找到返回 nil
    public static func theme(withId id: String) -> SyntaxTheme? {
        all.first { $0.id == id }
    }

    /// 根据外观获取默认主题
    /// - Parameter appearance: 目标外观
    /// - Returns: 对应的默认主题
    public static func defaultTheme(for appearance: SyntaxTheme.Appearance) -> SyntaxTheme {
        switch appearance {
        case .light:
            return light
        case .dark:
            return dark
        }
    }

    // MARK: - Private Helpers

    /// 构建 Token 样式映射
    private static func buildTokenStyles(
        keyword: NSColor,
        type: NSColor,
        string: NSColor,
        number: NSColor,
        comment: NSColor,
        function: NSColor,
        variable: NSColor,
        property: NSColor,
        constant: NSColor,
        attribute: NSColor,
        operator: NSColor,
        punctuation: NSColor,
        heading: NSColor,
        link: NSColor
    ) -> [String: TokenStyle] {
        [
            // Keywords（关键字使用粗体）
            CaptureNames.keyword: .bold(keyword),
            CaptureNames.keywordControl: .bold(keyword),
            CaptureNames.keywordFunction: .bold(keyword),
            CaptureNames.keywordReturn: .bold(keyword),
            CaptureNames.keywordOperator: .bold(keyword),

            // Types
            CaptureNames.type: .plain(type),
            CaptureNames.typeBuiltin: .plain(type),

            // Functions
            CaptureNames.function: .plain(function),
            CaptureNames.functionMethod: .plain(function),
            CaptureNames.functionBuiltin: .plain(function),
            CaptureNames.functionMacro: .plain(function),

            // Variables
            CaptureNames.variable: .plain(variable),
            CaptureNames.variableParameter: .plain(variable),
            CaptureNames.variableBuiltin: .bold(constant),

            // Literals
            CaptureNames.string: .plain(string),
            CaptureNames.stringSpecial: .plain(string),
            CaptureNames.number: .plain(number),
            CaptureNames.boolean: .bold(constant),
            CaptureNames.constant: .plain(constant),
            CaptureNames.constantBuiltin: .plain(constant),

            // Comments（注释使用斜体）
            CaptureNames.comment: .italic(comment),
            CaptureNames.commentDocumentation: .italic(comment),

            // Punctuation
            CaptureNames.punctuation: .plain(punctuation),
            CaptureNames.punctuationDelimiter: .plain(punctuation),
            CaptureNames.punctuationBracket: .plain(punctuation),

            // Operators
            CaptureNames.operator: .plain(`operator`),

            // Properties
            CaptureNames.property: .plain(property),

            // Labels
            CaptureNames.label: .plain(variable),

            // Attributes
            CaptureNames.attribute: .plain(attribute),

            // Markdown
            CaptureNames.markupHeading: .bold(heading),
            CaptureNames.markupBold: .bold(heading),
            CaptureNames.markupItalic: .italic(heading),
            CaptureNames.markupLink: .plain(link),
            CaptureNames.markupRaw: .plain(string),
            CaptureNames.markupList: .plain(punctuation),
        ]
    }
}

import Foundation
import Testing
import AppKit
import Combine
@testable import CodeVoyager

// MARK: - TokenStyle Tests

@Suite("TokenStyle Tests")
struct TokenStyleTests {

    // MARK: - Initialization Tests

    @Test("Default initialization creates plain style")
    func defaultInitialization() {
        let style = TokenStyle(color: .red)

        #expect(style.color == .red)
        #expect(style.isBold == false)
        #expect(style.isItalic == false)
    }

    @Test("Full initialization sets all properties")
    func fullInitialization() {
        let style = TokenStyle(color: .blue, isBold: true, isItalic: true)

        #expect(style.color == .blue)
        #expect(style.isBold == true)
        #expect(style.isItalic == true)
    }

    // MARK: - Convenience Initializers Tests

    @Test("plain() creates non-styled token")
    func plainStyle() {
        let style = TokenStyle.plain(.green)

        #expect(style.color == .green)
        #expect(style.isBold == false)
        #expect(style.isItalic == false)
    }

    @Test("bold() creates bold token")
    func boldStyle() {
        let style = TokenStyle.bold(.orange)

        #expect(style.color == .orange)
        #expect(style.isBold == true)
        #expect(style.isItalic == false)
    }

    @Test("italic() creates italic token")
    func italicStyle() {
        let style = TokenStyle.italic(.purple)

        #expect(style.color == .purple)
        #expect(style.isBold == false)
        #expect(style.isItalic == true)
    }

    @Test("boldItalic() creates bold and italic token")
    func boldItalicStyle() {
        let style = TokenStyle.boldItalic(.cyan)

        #expect(style.color == .cyan)
        #expect(style.isBold == true)
        #expect(style.isItalic == true)
    }

    // MARK: - Font Generation Tests

    @Test("Font returns base font for plain style")
    func fontForPlainStyle() {
        let baseFont = NSFont.systemFont(ofSize: 14)
        let style = TokenStyle.plain(.black)

        let resultFont = style.font(from: baseFont)

        #expect(resultFont.pointSize == baseFont.pointSize)
    }

    @Test("Font applies bold trait")
    func fontAppliesBold() {
        let baseFont = NSFont.systemFont(ofSize: 14)
        let style = TokenStyle.bold(.black)

        let resultFont = style.font(from: baseFont)

        let traits = resultFont.fontDescriptor.symbolicTraits
        #expect(traits.contains(.bold))
    }

    @Test("Font applies italic trait")
    func fontAppliesItalic() {
        let baseFont = NSFont.systemFont(ofSize: 14)
        let style = TokenStyle.italic(.black)

        let resultFont = style.font(from: baseFont)

        let traits = resultFont.fontDescriptor.symbolicTraits
        #expect(traits.contains(.italic))
    }

    @Test("Font applies both bold and italic traits")
    func fontAppliesBoldItalic() {
        let baseFont = NSFont.systemFont(ofSize: 14)
        let style = TokenStyle.boldItalic(.black)

        let resultFont = style.font(from: baseFont)

        let traits = resultFont.fontDescriptor.symbolicTraits
        #expect(traits.contains(.bold))
        #expect(traits.contains(.italic))
    }

    @Test("Font preserves point size")
    func fontPreservesPointSize() {
        let baseFont = NSFont.systemFont(ofSize: 18)
        let style = TokenStyle.bold(.black)

        let resultFont = style.font(from: baseFont)

        #expect(resultFont.pointSize == 18)
    }

    @Test("Font falls back to base font when traits unavailable")
    func fontFallsBackWhenTraitsUnavailable() {
        // 使用一个可能不支持所有 traits 的字体
        // 即使字体创建失败，也应该返回基础字体而非 nil
        // 注意：大多数系统字体都支持 bold/italic，所以这个测试主要验证不会崩溃
        guard let specialFont = NSFont(name: "Symbol", size: 14) else {
            // 如果 Symbol 字体不可用，使用系统字体
            let baseFont = NSFont.systemFont(ofSize: 14)
            let style = TokenStyle.boldItalic(.black)
            let resultFont = style.font(from: baseFont)

            // 无论如何都应该返回有效字体
            #expect(resultFont.pointSize == 14)
            return
        }

        let style = TokenStyle.boldItalic(.black)
        let resultFont = style.font(from: specialFont)

        // 无论成功与否，都应返回有效字体
        #expect(resultFont.pointSize == specialFont.pointSize)
    }

    // MARK: - Attributes Tests

    @Test("Attributes contains foreground color and font")
    func attributesContainsRequiredKeys() {
        let baseFont = NSFont.systemFont(ofSize: 14)
        let style = TokenStyle.bold(.red)

        let attrs = style.attributes(baseFont: baseFont)

        #expect(attrs[.foregroundColor] as? NSColor == .red)
        #expect(attrs[.font] != nil)
    }

    // MARK: - Equatable Tests

    @Test("Equal styles are equal")
    func equalStylesAreEqual() {
        let style1 = TokenStyle(color: .red, isBold: true, isItalic: false)
        let style2 = TokenStyle(color: .red, isBold: true, isItalic: false)

        #expect(style1 == style2)
    }

    @Test("Different styles are not equal")
    func differentStylesAreNotEqual() {
        let style1 = TokenStyle(color: .red, isBold: true, isItalic: false)
        let style2 = TokenStyle(color: .red, isBold: false, isItalic: false)

        #expect(style1 != style2)
    }

    // MARK: - Hashable Tests

    @Test("Equal styles have same hash")
    func equalStylesHaveSameHash() {
        let style1 = TokenStyle(color: .red, isBold: true, isItalic: false)
        let style2 = TokenStyle(color: .red, isBold: true, isItalic: false)

        #expect(style1.hashValue == style2.hashValue)
    }
}

// MARK: - SyntaxTheme.Appearance Tests

@Suite("SyntaxTheme.Appearance Tests")
struct SyntaxThemeAppearanceTests {

    @Test("Appearance has all expected cases")
    func appearanceHasAllCases() {
        let cases = SyntaxTheme.Appearance.allCases

        #expect(cases.count == 2)
        #expect(cases.contains(.light))
        #expect(cases.contains(.dark))
    }

    @Test("Appearance raw values are correct")
    func appearanceRawValues() {
        #expect(SyntaxTheme.Appearance.light.rawValue == "light")
        #expect(SyntaxTheme.Appearance.dark.rawValue == "dark")
    }

    @Test("Appearance can be initialized from raw value")
    func appearanceFromRawValue() {
        #expect(SyntaxTheme.Appearance(rawValue: "light") == .light)
        #expect(SyntaxTheme.Appearance(rawValue: "dark") == .dark)
        #expect(SyntaxTheme.Appearance(rawValue: "invalid") == nil)
    }

    // MARK: - matches(systemAppearance:) Tests

    @Test("matches returns false for nil appearance")
    func matchesReturnsFalseForNil() {
        #expect(SyntaxTheme.Appearance.light.matches(systemAppearance: nil) == false)
        #expect(SyntaxTheme.Appearance.dark.matches(systemAppearance: nil) == false)
    }

    @Test("light matches aqua appearance")
    func lightMatchesAqua() {
        let aquaAppearance = NSAppearance(named: .aqua)
        #expect(SyntaxTheme.Appearance.light.matches(systemAppearance: aquaAppearance) == true)
        #expect(SyntaxTheme.Appearance.dark.matches(systemAppearance: aquaAppearance) == false)
    }

    @Test("dark matches darkAqua appearance")
    func darkMatchesDarkAqua() {
        let darkAppearance = NSAppearance(named: .darkAqua)
        #expect(SyntaxTheme.Appearance.dark.matches(systemAppearance: darkAppearance) == true)
        #expect(SyntaxTheme.Appearance.light.matches(systemAppearance: darkAppearance) == false)
    }

    @Test("light matches vibrantLight appearance")
    func lightMatchesVibrantLight() {
        let vibrantLightAppearance = NSAppearance(named: .vibrantLight)
        #expect(SyntaxTheme.Appearance.light.matches(systemAppearance: vibrantLightAppearance) == true)
        #expect(SyntaxTheme.Appearance.dark.matches(systemAppearance: vibrantLightAppearance) == false)
    }

    @Test("dark matches vibrantDark appearance")
    func darkMatchesVibrantDark() {
        let vibrantDarkAppearance = NSAppearance(named: .vibrantDark)
        #expect(SyntaxTheme.Appearance.dark.matches(systemAppearance: vibrantDarkAppearance) == true)
        #expect(SyntaxTheme.Appearance.light.matches(systemAppearance: vibrantDarkAppearance) == false)
    }
}

// MARK: - ThemePreference Tests

@Suite("ThemePreference Tests")
struct ThemePreferenceTests {

    // MARK: - Case Tests

    @Test("followSystem case has no themeId")
    func followSystemHasNoThemeId() {
        let preference = ThemePreference.followSystem

        #expect(preference.themeId == nil)
        #expect(preference.isFollowingSystem == true)
    }

    @Test("manual case has themeId")
    func manualHasThemeId() {
        let preference = ThemePreference.manual(themeId: "dark")

        #expect(preference.themeId == "dark")
        #expect(preference.isFollowingSystem == false)
    }

    // MARK: - Equatable Tests

    @Test("Same preferences are equal")
    func samePreferencesAreEqual() {
        #expect(ThemePreference.followSystem == ThemePreference.followSystem)
        #expect(ThemePreference.manual(themeId: "dark") == ThemePreference.manual(themeId: "dark"))
    }

    @Test("Different preferences are not equal")
    func differentPreferencesAreNotEqual() {
        #expect(ThemePreference.followSystem != ThemePreference.manual(themeId: "dark"))
        #expect(ThemePreference.manual(themeId: "light") != ThemePreference.manual(themeId: "dark"))
    }

    // MARK: - Codable Tests

    @Test("followSystem can be encoded and decoded")
    func followSystemCodable() throws {
        let original = ThemePreference.followSystem

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ThemePreference.self, from: data)

        #expect(decoded == original)
    }

    @Test("manual can be encoded and decoded")
    func manualCodable() throws {
        let original = ThemePreference.manual(themeId: "my-theme")

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ThemePreference.self, from: data)

        #expect(decoded == original)
        #expect(decoded.themeId == "my-theme")
    }
}

// MARK: - SyntaxTheme Tests

@Suite("SyntaxTheme Tests")
struct SyntaxThemeTests {

    // MARK: - Initialization Tests

    @Test("Theme initializes with all properties")
    func themeInitialization() {
        let theme = SyntaxTheme(
            id: "test-theme",
            name: "Test Theme",
            appearance: .dark,
            backgroundColor: .black,
            lineNumberColor: .gray,
            currentLineBackgroundColor: .darkGray,
            selectionBackgroundColor: .blue,
            defaultStyle: .plain(.white),
            tokenStyles: ["keyword": .bold(.cyan)]
        )

        #expect(theme.id == "test-theme")
        #expect(theme.name == "Test Theme")
        #expect(theme.appearance == .dark)
        #expect(theme.backgroundColor == .black)
        #expect(theme.lineNumberColor == .gray)
        #expect(theme.currentLineBackgroundColor == .darkGray)
        #expect(theme.selectionBackgroundColor == .blue)
        #expect(theme.defaultStyle == .plain(.white))
        #expect(theme.tokenStyles.count == 1)
    }

    // MARK: - Style Lookup Tests

    @Test("style(for:) returns matching style")
    func styleForMatchingCapture() {
        let keywordStyle = TokenStyle.bold(.blue)
        let theme = createTestTheme(tokenStyles: ["keyword": keywordStyle])

        let result = theme.style(for: "keyword")

        #expect(result == keywordStyle)
    }

    @Test("style(for:) returns default for unknown capture")
    func styleForUnknownCapture() {
        let defaultStyle = TokenStyle.plain(.white)
        let theme = createTestTheme(defaultStyle: defaultStyle, tokenStyles: [:])

        let result = theme.style(for: "unknown.capture")

        #expect(result == defaultStyle)
    }

    @Test("style(for:) does not do hierarchical fallback")
    func styleNoHierarchicalFallback() {
        let keywordStyle = TokenStyle.bold(.blue)
        let defaultStyle = TokenStyle.plain(.white)
        let theme = createTestTheme(
            defaultStyle: defaultStyle,
            tokenStyles: ["keyword": keywordStyle]
        )

        // "keyword.control" should NOT fall back to "keyword"
        let result = theme.style(for: "keyword.control")

        #expect(result == defaultStyle)
    }

    // MARK: - Attributes Tests

    @Test("attributes(for:baseFont:) returns correct attributes")
    func attributesForCapture() {
        let keywordStyle = TokenStyle.bold(.blue)
        let theme = createTestTheme(tokenStyles: ["keyword": keywordStyle])
        let baseFont = NSFont.systemFont(ofSize: 14)

        let attrs = theme.attributes(for: "keyword", baseFont: baseFont)

        #expect(attrs[.foregroundColor] as? NSColor == .blue)
        #expect(attrs[.font] != nil)
    }

    // MARK: - Identifiable Tests

    @Test("Theme conforms to Identifiable")
    func themeIsIdentifiable() {
        let theme = createTestTheme(id: "unique-id")

        #expect(theme.id == "unique-id")
    }

    // MARK: - Equatable Tests

    @Test("Themes with same ID are equal")
    func themesWithSameIdAreEqual() {
        let theme1 = createTestTheme(id: "same-id", name: "Theme 1")
        let theme2 = createTestTheme(id: "same-id", name: "Theme 2")

        #expect(theme1 == theme2)
    }

    @Test("Themes with different IDs are not equal")
    func themesWithDifferentIdsAreNotEqual() {
        let theme1 = createTestTheme(id: "id-1")
        let theme2 = createTestTheme(id: "id-2")

        #expect(theme1 != theme2)
    }

    // MARK: - Hashable Tests

    @Test("Themes with same ID have same hash")
    func themesWithSameIdHaveSameHash() {
        let theme1 = createTestTheme(id: "same-id", name: "Theme 1")
        let theme2 = createTestTheme(id: "same-id", name: "Theme 2")

        #expect(theme1.hashValue == theme2.hashValue)
    }

    // MARK: - Helper

    private func createTestTheme(
        id: String = "test",
        name: String = "Test",
        appearance: SyntaxTheme.Appearance = .light,
        defaultStyle: TokenStyle = .plain(.black),
        tokenStyles: [String: TokenStyle] = [:]
    ) -> SyntaxTheme {
        SyntaxTheme(
            id: id,
            name: name,
            appearance: appearance,
            backgroundColor: .white,
            lineNumberColor: .gray,
            currentLineBackgroundColor: .lightGray,
            selectionBackgroundColor: .blue,
            defaultStyle: defaultStyle,
            tokenStyles: tokenStyles
        )
    }
}

// MARK: - DefaultThemes Tests

@Suite("DefaultThemes Tests")
struct DefaultThemesTests {

    @Test("Light theme exists and has correct properties")
    func lightThemeExists() {
        let light = DefaultThemes.light

        #expect(light.id == "light")
        #expect(light.name == "Light+")
        #expect(light.appearance == .light)
    }

    @Test("Dark theme exists and has correct properties")
    func darkThemeExists() {
        let dark = DefaultThemes.dark

        #expect(dark.id == "dark")
        #expect(dark.name == "Dark+")
        #expect(dark.appearance == .dark)
    }

    @Test("all contains both themes")
    func allContainsBothThemes() {
        let all = DefaultThemes.all

        #expect(all.count == 2)
        #expect(all.contains(DefaultThemes.light))
        #expect(all.contains(DefaultThemes.dark))
    }

    @Test("theme(withId:) returns correct theme")
    func themeWithId() {
        #expect(DefaultThemes.theme(withId: "light") == DefaultThemes.light)
        #expect(DefaultThemes.theme(withId: "dark") == DefaultThemes.dark)
        #expect(DefaultThemes.theme(withId: "nonexistent") == nil)
    }

    @Test("defaultTheme(for:) returns appropriate theme")
    func defaultThemeForAppearance() {
        #expect(DefaultThemes.defaultTheme(for: .light) == DefaultThemes.light)
        #expect(DefaultThemes.defaultTheme(for: .dark) == DefaultThemes.dark)
    }

    @Test("Themes have required token styles")
    func themesHaveRequiredTokenStyles() {
        for theme in DefaultThemes.all {
            // 验证常用的 token styles 存在
            #expect(theme.tokenStyles[CaptureNames.keyword] != nil)
            #expect(theme.tokenStyles[CaptureNames.string] != nil)
            #expect(theme.tokenStyles[CaptureNames.comment] != nil)
            #expect(theme.tokenStyles[CaptureNames.function] != nil)
            #expect(theme.tokenStyles[CaptureNames.type] != nil)
            #expect(theme.tokenStyles[CaptureNames.number] != nil)
        }
    }

    @Test("Keywords are bold in both themes")
    func keywordsAreBold() {
        for theme in DefaultThemes.all {
            let keywordStyle = theme.tokenStyles[CaptureNames.keyword]
            #expect(keywordStyle?.isBold == true)
        }
    }

    @Test("Comments are italic in both themes")
    func commentsAreItalic() {
        for theme in DefaultThemes.all {
            let commentStyle = theme.tokenStyles[CaptureNames.comment]
            #expect(commentStyle?.isItalic == true)
        }
    }
}

// MARK: - ThemeManager Tests

@Suite("ThemeManager Tests")
@MainActor
struct ThemeManagerTests {

    // MARK: - Setup

    /// 测试用的独立 ThemeManager
    /// 每个测试方法使用新实例避免状态污染
    private func createTestManager() -> ThemeManager {
        let manager = ThemeManager()
        manager.reset() // 确保初始状态
        return manager
    }

    // MARK: - Initialization Tests

    @Test("ThemeManager initializes with followSystem preference by default")
    func defaultInitialization() async {
        // 清除可能存在的偏好
        UserDefaults.standard.removeObject(forKey: "CodeVoyager.ThemeManager.preference")

        let manager = ThemeManager()

        #expect(manager.preference == .followSystem)
        // currentTheme 应该是 light 或 dark，取决于系统外观
        #expect(manager.currentTheme == DefaultThemes.light || manager.currentTheme == DefaultThemes.dark)
    }

    @Test("ThemeManager availableThemes returns all default themes")
    func availableThemes() async {
        let manager = createTestManager()

        #expect(manager.availableThemes.count == 2)
        #expect(manager.availableThemes.contains(DefaultThemes.light))
        #expect(manager.availableThemes.contains(DefaultThemes.dark))
    }

    // MARK: - setTheme Tests

    @Test("setTheme changes currentTheme")
    func setThemeChangesCurrentTheme() async {
        let manager = createTestManager()

        manager.setTheme(DefaultThemes.dark)

        #expect(manager.currentTheme == DefaultThemes.dark)
    }

    @Test("setTheme changes preference to manual")
    func setThemeChangesPreference() async {
        let manager = createTestManager()

        manager.setTheme(DefaultThemes.dark)

        #expect(manager.preference == .manual(themeId: "dark"))
    }

    @Test("setTheme(withId:) returns true for valid ID")
    func setThemeWithValidId() async {
        let manager = createTestManager()

        let result = manager.setTheme(withId: "dark")

        #expect(result == true)
        #expect(manager.currentTheme == DefaultThemes.dark)
    }

    @Test("setTheme(withId:) returns false for invalid ID")
    func setThemeWithInvalidId() async {
        let manager = createTestManager()
        let originalTheme = manager.currentTheme

        let result = manager.setTheme(withId: "nonexistent")

        #expect(result == false)
        #expect(manager.currentTheme == originalTheme) // 主题不变
    }

    // MARK: - setFollowSystem Tests

    @Test("setFollowSystem changes preference")
    func setFollowSystemChangesPreference() async {
        let manager = createTestManager()

        // 先设置为手动
        manager.setTheme(DefaultThemes.dark)
        #expect(manager.preference == .manual(themeId: "dark"))

        // 恢复跟随系统
        manager.setFollowSystem()

        #expect(manager.preference == .followSystem)
    }

    // MARK: - updateForSystemAppearance Tests

    @Test("updateForSystemAppearance does nothing when preference is manual")
    func updateForSystemAppearanceManual() async {
        let manager = createTestManager()

        // 设置为手动 light
        manager.setTheme(DefaultThemes.light)
        let originalTheme = manager.currentTheme

        // 调用更新
        manager.updateForSystemAppearance()

        // 主题应该不变
        #expect(manager.currentTheme == originalTheme)
    }

    // MARK: - themeDidChange Publisher Tests

    @Test("themeDidChange publishes when theme changes")
    func themeDidChangePublishes() async {
        let manager = createTestManager()

        var receivedThemes: [SyntaxTheme] = []
        let cancellable = manager.themeDidChange.sink { theme in
            receivedThemes.append(theme)
        }

        // 切换主题
        manager.setTheme(DefaultThemes.dark)

        // 等待一小段时间确保事件发送
        try? await Task.sleep(for: .milliseconds(10))

        #expect(receivedThemes.count >= 1)
        #expect(receivedThemes.last == DefaultThemes.dark)

        _ = cancellable
    }

    @Test("themeDidChange does not publish when setting same theme")
    func themeDidChangeNotPublishForSameTheme() async {
        let manager = createTestManager()

        // 先设置为 dark
        manager.setTheme(DefaultThemes.dark)

        var receivedCount = 0
        let cancellable = manager.themeDidChange.sink { _ in
            receivedCount += 1
        }

        // 再次设置为 dark
        manager.setTheme(DefaultThemes.dark)

        // 等待一小段时间
        try? await Task.sleep(for: .milliseconds(10))

        // 不应该发送事件
        #expect(receivedCount == 0)

        _ = cancellable
    }

    // MARK: - Persistence Tests

    @Test("Theme preference persists across instances")
    func preferencePersists() async {
        // 使用特定 key 避免与其他测试冲突
        let testKey = "CodeVoyager.ThemeManager.preference"

        // 第一个实例设置主题
        let manager1 = ThemeManager()
        manager1.setTheme(DefaultThemes.dark)

        // 验证 UserDefaults 中有数据
        let savedData = UserDefaults.standard.data(forKey: testKey)
        #expect(savedData != nil)

        // 第二个实例应该加载已保存的偏好
        let manager2 = ThemeManager()
        #expect(manager2.preference == .manual(themeId: "dark"))
        #expect(manager2.currentTheme == DefaultThemes.dark)

        // 清理
        manager1.reset()
    }

    // MARK: - reset Tests

    @Test("reset restores default state")
    func resetRestoresDefault() async {
        let manager = createTestManager()

        // 设置为手动主题
        manager.setTheme(DefaultThemes.dark)
        #expect(manager.preference == .manual(themeId: "dark"))

        // 重置
        manager.reset()

        #expect(manager.preference == .followSystem)
    }
}

// MARK: - CaptureNames Tests

@Suite("CaptureNames Tests")
struct CaptureNamesTests {

    @Test("Keyword capture names are correct")
    func keywordCaptureNames() {
        #expect(CaptureNames.keyword == "keyword")
        #expect(CaptureNames.keywordControl == "keyword.control")
        #expect(CaptureNames.keywordFunction == "keyword.function")
        #expect(CaptureNames.keywordReturn == "keyword.return")
        #expect(CaptureNames.keywordOperator == "keyword.operator")
    }

    @Test("Type capture names are correct")
    func typeCaptureNames() {
        #expect(CaptureNames.type == "type")
        #expect(CaptureNames.typeBuiltin == "type.builtin")
    }

    @Test("Function capture names are correct")
    func functionCaptureNames() {
        #expect(CaptureNames.function == "function")
        #expect(CaptureNames.functionMethod == "function.method")
        #expect(CaptureNames.functionBuiltin == "function.builtin")
        #expect(CaptureNames.functionMacro == "function.macro")
    }

    @Test("Variable capture names are correct")
    func variableCaptureNames() {
        #expect(CaptureNames.variable == "variable")
        #expect(CaptureNames.variableParameter == "variable.parameter")
        #expect(CaptureNames.variableBuiltin == "variable.builtin")
    }

    @Test("Literal capture names are correct")
    func literalCaptureNames() {
        #expect(CaptureNames.string == "string")
        #expect(CaptureNames.stringSpecial == "string.special")
        #expect(CaptureNames.stringEscape == "string.escape")
        #expect(CaptureNames.number == "number")
        #expect(CaptureNames.boolean == "boolean")
        #expect(CaptureNames.constant == "constant")
        #expect(CaptureNames.constantBuiltin == "constant.builtin")
    }

    @Test("Comment capture names are correct")
    func commentCaptureNames() {
        #expect(CaptureNames.comment == "comment")
        #expect(CaptureNames.commentDocumentation == "comment.documentation")
    }

    @Test("Punctuation capture names are correct")
    func punctuationCaptureNames() {
        #expect(CaptureNames.punctuation == "punctuation")
        #expect(CaptureNames.punctuationDelimiter == "punctuation.delimiter")
        #expect(CaptureNames.punctuationBracket == "punctuation.bracket")
        #expect(CaptureNames.punctuationSpecial == "punctuation.special")
    }

    @Test("Operator capture name is correct")
    func operatorCaptureName() {
        #expect(CaptureNames.operator == "operator")
    }

    @Test("Property capture name is correct")
    func propertyCaptureName() {
        #expect(CaptureNames.property == "property")
    }

    @Test("Label capture name is correct")
    func labelCaptureName() {
        #expect(CaptureNames.label == "label")
    }

    @Test("Attribute capture name is correct")
    func attributeCaptureName() {
        #expect(CaptureNames.attribute == "attribute")
    }

    @Test("Markdown capture names are correct")
    func markdownCaptureNames() {
        #expect(CaptureNames.markupHeading == "markup.heading")
        #expect(CaptureNames.markupBold == "markup.bold")
        #expect(CaptureNames.markupItalic == "markup.italic")
        #expect(CaptureNames.markupLink == "markup.link")
        #expect(CaptureNames.markupRaw == "markup.raw")
        #expect(CaptureNames.markupList == "markup.list")
        #expect(CaptureNames.textTitle == "text.title")
        #expect(CaptureNames.textLiteral == "text.literal")
        #expect(CaptureNames.textURI == "text.uri")
        #expect(CaptureNames.textReference == "text.reference")
        #expect(CaptureNames.textEmphasis == "text.emphasis")
        #expect(CaptureNames.textStrong == "text.strong")
    }
}

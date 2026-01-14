# 字符串处理最佳实践

## 行数计算

### 问题

使用 `components(separatedBy: .newlines)` 计算行数时有两个陷阱：

1. **空字符串返回 `[""]`**，count 为 1（而非 0）
2. **以换行符结尾的内容会产生空的末尾元素**

```swift
// ❌ 错误实现
let lineCount = content.components(separatedBy: .newlines).count

// 结果：
// "" → 1 (应该是 0)
// "hello" → 1 ✓
// "hello\nworld" → 2 ✓
// "hello\nworld\n" → 3 (应该是 2)
```

### 推荐实现

```swift
// ✅ 正确实现
private static func calculateLineCount(_ content: String) -> Int {
    if content.isEmpty { return 0 }
    
    let components = content.components(separatedBy: .newlines)
    let count = components.count
    
    // 如果内容以换行符结尾，最后一个元素是空字符串
    // 不应将其计为一行
    if let last = components.last, last.isEmpty {
        return max(0, count - 1)
    }
    
    return count
}

// 结果：
// "" → 0 ✓
// "hello" → 1 ✓
// "hello\nworld" → 2 ✓
// "hello\nworld\n" → 2 ✓
```

### 测试用例

```swift
@Test("Empty content has 0 lines")
func lineCountEmpty() {
    let content = FileContent(path: "/test/empty.txt", content: "")
    #expect(content.lineCount == 0)
}

@Test("Single line without newline")
func lineCountSingle() {
    let content = FileContent(path: "/test/single.txt", content: "Hello")
    #expect(content.lineCount == 1)
}

@Test("Content ending with newline")
func lineCountTrailing() {
    let content = FileContent(path: "/test/trailing.txt", content: "Line 1\nLine 2\n")
    #expect(content.lineCount == 2)
}
```

## 安全的前缀/后缀提取

### `String.prefix(_:)` 行为

`prefix(_:)` 对短于指定长度的字符串会返回原字符串本身，这是安全的行为：

```swift
let sha = "abc"
let short = String(sha.prefix(7))  // 返回 "abc"，不会崩溃
```

### 必须测试的边界情况

```swift
@Test("shortSHA handles empty string")
func shortSHAEmpty() {
    let commit = makeCommit(sha: "")
    #expect(commit.shortSHA == "")
}

@Test("shortSHA handles string shorter than 7 characters")
func shortSHAShorterThan7() {
    let commit = makeCommit(sha: "abc")
    #expect(commit.shortSHA == "abc")
}

@Test("shortSHA handles exactly 7 characters")
func shortSHAExactly7() {
    let commit = makeCommit(sha: "abc1234")
    #expect(commit.shortSHA == "abc1234")
}

@Test("shortSHA returns first 7 characters for longer strings")
func shortSHALonger() {
    let commit = makeCommit(sha: "abc123def456789")
    #expect(commit.shortSHA == "abc123d")
}
```

## 字符串分割边界情况

### 空字符串分割

```swift
"".split(separator: "/")           // 返回 []
"".components(separatedBy: "/")    // 返回 [""]
```

**注意**：`split` 和 `components` 对空字符串的处理不同！

### 连续分隔符

```swift
"a//b".split(separator: "/")           // 返回 ["a", "b"]
"a//b".components(separatedBy: "/")    // 返回 ["a", "", "b"]
```

### 推荐做法

- 需要保留空元素时用 `components(separatedBy:)`
- 需要过滤空元素时用 `split(separator:)`

## 检查清单

在处理字符串时，确保测试以下场景：

- [ ] 空字符串
- [ ] 只有分隔符的字符串（如 `"\n"`, `"/"`)
- [ ] 以分隔符开头的字符串
- [ ] 以分隔符结尾的字符串
- [ ] 连续分隔符
- [ ] 长度不足的字符串（对于 `prefix`/`suffix`）
- [ ] 恰好达到阈值的字符串

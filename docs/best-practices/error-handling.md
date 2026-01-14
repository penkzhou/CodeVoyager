# 错误处理最佳实践

## 原则

1. **禁止静默失败** - 所有错误必须被记录或处理
2. **提供可操作指引** - 错误消息应告诉用户如何解决问题
3. **适当的恢复策略** - 根据错误类型选择合适的恢复方式

## 反模式：静默吞掉错误

### ❌ 不推荐

```swift
private func loadData() {
    guard let data = UserDefaults.standard.data(forKey: "key"),
          let decoded = try? JSONDecoder().decode(Model.self, from: data) else {
        return  // 静默失败，无法调试
    }
    self.model = decoded
}
```

**问题**：
- 无法知道是因为数据不存在还是解码失败
- 生产环境出问题时难以排查
- 用户看到空数据但不知道原因

### ✅ 推荐

```swift
private func loadData() {
    guard let data = UserDefaults.standard.data(forKey: "key") else {
        logger.debug("No data found in UserDefaults")
        return
    }
    
    do {
        let decoded = try JSONDecoder().decode(Model.self, from: data)
        self.model = decoded
        logger.debug("Loaded \(decoded.count) items")
    } catch {
        logger.error("Failed to decode data: \(error.localizedDescription)")
        // 清理损坏数据，防止重复失败
        UserDefaults.standard.removeObject(forKey: "key")
    }
}
```

## 用户友好的错误消息

### ❌ 不推荐

```swift
errorMessage = "Invalid path"
errorMessage = "Not a Git repository"
errorMessage = "Failed to load"
```

### ✅ 推荐

```swift
errorMessage = "This directory is not a Git repository. Please select a directory containing a .git folder, or initialize a new repository using 'git init' in the terminal."

errorMessage = "Unable to open file. The file may have been moved or deleted. Please check if the file exists at: \(path)"

errorMessage = "Failed to connect to the server. Please check your internet connection and try again."
```

## 错误恢复策略

### 1. 可恢复错误 - 提示用户重试

```swift
func fetchData() async {
    do {
        data = try await api.fetch()
    } catch {
        errorMessage = "Failed to load data. Tap to retry."
        showRetryButton = true
        logger.error("API fetch failed: \(error)")
    }
}
```

### 2. 数据损坏 - 清理并重置

```swift
func loadCache() {
    do {
        cache = try decoder.decode(Cache.self, from: data)
    } catch {
        logger.error("Cache corrupted, resetting: \(error)")
        cache = Cache()
        clearCacheFile()
    }
}
```

### 3. 致命错误 - 优雅降级

```swift
func initializeDatabase() {
    do {
        database = try Database(path: dbPath)
    } catch {
        logger.error("Database init failed: \(error)")
        // 降级到只读内存模式
        database = Database.inMemory()
        showWarning("Running in limited mode due to database error")
    }
}
```

## 日志级别指南

| 级别 | 使用场景 |
|------|----------|
| `debug` | 正常流程信息，如 "Loaded 5 items" |
| `info` | 重要业务事件，如 "User opened repository" |
| `warning` | 可恢复的异常，如 "File not found, using default" |
| `error` | 需要关注的错误，如 "Decode failed" |
| `fault` | 严重错误，如 "Database corruption detected" |

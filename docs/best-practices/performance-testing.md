# 性能测试最佳实践

## 避免墙钟时间硬编码

### 问题

在单元测试中使用紧凑的时间限制（如 `elapsed < 0.1`）会导致：

- **CI 环境假阴性**：GitHub Actions 等 CI 系统资源受限，运行速度可能比本地慢 5-10 倍
- **Debug 构建假阴性**：优化未开启、断言开销、额外的运行时检查
- **环境差异**：ARC 引用计数、锁竞争、日志输出、GC 等因素影响执行时间
- **机器差异**：不同 CPU、内存、磁盘 IO 导致行为不一致

### 解决方案

#### 1. 使用宽松阈值

```swift
// ❌ 过于紧凑 - 容易在 CI 或 Debug 构建下失败
#expect(elapsed < 0.1, "100 cached retrievals took \(elapsed)s")

// ✅ 宽松阈值 - 用于检测严重的性能退化
#expect(elapsed < 1.0, "100 cached retrievals took \(elapsed)s")
```

**经验法则**：阈值设为预期值的 10x~100x，确保只有真正的性能退化才会触发失败。

#### 2. 添加解释性注释

```swift
// 100 次缓存读取应在 1 秒内完成
// 使用宽松阈值（平均每次 10ms）以避免 CI 环境或 Debug 构建下的假阴性
// 实际性能应远优于此阈值，此测试主要用于检测严重的性能退化
#expect(elapsed < 1.0, "100 cached retrievals took \(elapsed)s, expected < 1.0s")
```

#### 3. 区分性能测试类型

| 类型 | 目的 | 阈值策略 | 运行频率 |
|------|------|----------|----------|
| 回归检测 | 防止严重性能退化 | 宽松 (10x-100x) | 每次 CI |
| 性能基准 | 精确测量性能 | 严格 | 手动/定期 |
| 性能对比 | A/B 比较 | 相对比较 | 按需 |

#### 4. 精确性能测试使用专门工具

对于需要精确测量的场景：

```swift
// 使用 XCTest 的 measure API（自动多次运行并统计）
func testCachePerformance() throws {
    let registry = LanguageRegistry()
    _ = try registry.configuration(for: .swift) // 预热
    
    measure {
        for _ in 0..<100 {
            _ = try? registry.configuration(for: .swift)
        }
    }
}
```

其他精确测量工具：
- **Instruments Profiling**：CPU、内存、IO 详细分析
- **XCTest Performance Baselines**：基于历史数据的回归检测
- **独立性能测试套件**：不在常规 CI 中运行，避免影响开发流程

### 示例：大文件处理性能测试

```swift
@Test("Large file processing completes within acceptable time")
func largeFileProcessingPerformance() {
    let largeContent = generateCode(lineCount: 10000)
    
    let startTime = CFAbsoluteTimeGetCurrent()
    _ = processContent(largeContent)
    let elapsed = CFAbsoluteTimeGetCurrent() - startTime
    
    // 10k 行文件处理应在 5 秒内完成
    // 使用宽松阈值以适应不同环境：
    // - 本地 Release: ~100ms
    // - 本地 Debug: ~500ms  
    // - CI Debug: ~2s
    // 阈值 5s 可检测 10x 以上的性能退化
    #expect(elapsed < 5.0, "Processing took \(elapsed)s, expected < 5.0s")
}
```

### 相关资源

- [Swift Testing 框架文档](https://developer.apple.com/documentation/testing)
- [XCTest Performance Testing](https://developer.apple.com/documentation/xctest/performance_tests)

# C API 与 Unmanaged 内存安全

## 概述

在 Swift 中与 C API（如 FSEvents、Core Foundation）交互时，经常需要使用 `Unmanaged` 类型传递对象引用。如果处理不当，会导致内存泄漏或悬空指针崩溃。

## FSEvents 回调的正确模式

### ❌ 不安全的方式

```swift
var context = FSEventStreamContext(
    version: 0,
    info: Unmanaged.passUnretained(self).toOpaque(),  // 危险！
    retain: nil,
    release: nil,
    copyDescription: nil
)
```

**问题**：`passUnretained` 不增加引用计数。如果 `self` 在回调执行前被释放，会导致悬空指针。

### ✅ 安全的方式

```swift
// 定义 retain/release 回调
let retainCallback: CFAllocatorRetainCallBack = { info in
    guard let info = info else { return nil }
    _ = Unmanaged<MyWatcher>.fromOpaque(info).retain()
    return UnsafeRawPointer(info)
}

let releaseCallback: CFAllocatorReleaseCallBack = { info in
    guard let info = info else { return }
    Unmanaged<MyWatcher>.fromOpaque(info).release()
}

var context = FSEventStreamContext(
    version: 0,
    info: Unmanaged.passRetained(self).toOpaque(),  // 增加引用计数
    retain: retainCallback,    // 框架复制时增加计数
    release: releaseCallback,  // 框架释放时减少计数
    copyDescription: nil
)
```

**关键点**：
1. 使用 `passRetained` 而非 `passUnretained`
2. 提供 `retain` 和 `release` 回调让框架管理引用计数
3. `FSEventStreamRelease` 会调用 `release` 回调，平衡初始的 `passRetained`

## 回调中安全访问对象

```swift
let callback: FSEventStreamCallback = { _, info, numEvents, eventPaths, eventFlags, _ in
    guard let info = info else { return }
    // 使用 takeUnretainedValue() 因为我们已通过 retain/release 回调管理引用计数
    let watcher = Unmanaged<MyWatcher>.fromOpaque(info).takeUnretainedValue()
    watcher.handleEvents(...)
}
```

## 通用原则

| 方法 | 引用计数 | 适用场景 |
|------|----------|----------|
| `passUnretained` | 不变 | 同步调用，确保对象不会被释放 |
| `passRetained` | +1 | 异步回调，需要确保对象存活 |
| `takeUnretainedValue` | 不变 | 读取引用，不获取所有权 |
| `takeRetainedValue` | -1 | 获取所有权并减少计数 |

## 清理模式

```swift
func invalidate() {
    if let stream = stream {
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        // FSEventStreamRelease 会调用 release 回调
        FSEventStreamRelease(stream)
    }
    stream = nil
}

deinit {
    invalidate()
}
```

## 检查清单

- [ ] 是否使用 `passRetained` 而非 `passUnretained` 传递给异步回调？
- [ ] 是否提供了 `retain` 和 `release` 回调？
- [ ] `invalidate()` 方法是否在 `deinit` 中调用？
- [ ] 回调中是否使用 `takeUnretainedValue()` 访问对象？

## 参考实现

- `Sources/CodeVoyager/Services/FileSystem/FileSystemService.swift` - `FSEventsWatcher`

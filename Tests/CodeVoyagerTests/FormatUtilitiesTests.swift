import Foundation
import Testing
@testable import CodeVoyager

@Suite("FormatUtilities Tests")
struct FormatUtilitiesTests {
    
    // MARK: - formatFileSize Tests
    
    @Test("formatFileSize formats zero bytes")
    func formatFileSizeZero() {
        let result = FormatUtilities.formatFileSize(0)
        #expect(result == "Zero KB" || result == "0 bytes" || result.contains("0"))
    }
    
    @Test("formatFileSize formats bytes (< 1KB)")
    func formatFileSizeBytes() {
        let result = FormatUtilities.formatFileSize(500)
        // ByteCountFormatter with .file style may show "500 bytes" or similar
        #expect(result.contains("500") || result.contains("bytes") || result.contains("KB"))
    }
    
    @Test("formatFileSize formats kilobytes")
    func formatFileSizeKB() {
        let result = FormatUtilities.formatFileSize(1024)
        // Should show approximately 1 KB
        #expect(result.contains("1") && (result.contains("KB") || result.contains("kB")))
    }
    
    @Test("formatFileSize formats megabytes")
    func formatFileSizeMB() {
        let result = FormatUtilities.formatFileSize(1024 * 1024)
        // Should show approximately 1 MB
        #expect(result.contains("1") && result.contains("MB"))
    }
    
    @Test("formatFileSize formats gigabytes")
    func formatFileSizeGB() {
        let result = FormatUtilities.formatFileSize(1024 * 1024 * 1024)
        // Should show approximately 1 GB
        #expect(result.contains("1") && result.contains("GB"))
    }
    
    @Test("formatFileSize formats large file (50MB)")
    func formatFileSizeLargeFile() {
        let fiftyMB: Int64 = 50 * 1024 * 1024
        let result = FormatUtilities.formatFileSize(fiftyMB)
        // ByteCountFormatter with .file style shows 52.4 MB (50 * 1024 * 1024 = 52,428,800 bytes)
        // Note: .file style uses 1000-based units, so 52,428,800 / 1,000,000 ≈ 52.4
        #expect(result.contains("MB"))
    }
    
    @Test("formatFileSize formats typical source file size")
    func formatFileSizeTypicalSourceFile() {
        // A typical source file might be around 10KB
        let result = FormatUtilities.formatFileSize(10 * 1024)
        #expect(result.contains("10") && (result.contains("KB") || result.contains("kB")))
    }
    
    @Test("formatFileSize handles exact boundary values")
    func formatFileSizeBoundaries() {
        // Test boundary between KB and MB (1024 KB = 1 MB)
        let oneMB: Int64 = 1024 * 1024
        let result = FormatUtilities.formatFileSize(oneMB)
        #expect(result.contains("MB") || result.contains("1,024"))
    }
}

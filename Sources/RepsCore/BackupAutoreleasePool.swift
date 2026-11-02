import Foundation

// Foundation/CryptoKit bridge through Objective-C on iOS. A synchronous long-running
// backup loop must drain temporary objects per record, rather than at the end of the job.
public enum BackupAutoreleasePool {
  public static func withPool<T>(_ body: () throws -> T) rethrows -> T {
    #if canImport(ObjectiveC)
      return try autoreleasepool(invoking: body)
    #else
      return try body()
    #endif
  }
}

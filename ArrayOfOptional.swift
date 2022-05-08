import LoftDataStructures_BitVector

private extension Optional {
  mutating func release() -> Wrapped {
    defer { self = nil }
    return self!
  }

  mutating func unsafeRelease() -> Wrapped {
    defer { self = nil }
    return unsafelyUnwrapped
  }
}

private struct Header {
  var isOccupied: BitVector
  var capacity: Int
}

// FIXME: This is suboptimal; there should be one buffer for the bits and the
// Ts, all stored inline.
private final class Buffer<T>: ManagedBuffer<Header, T> {
  deinit {
    withUnsafeMutablePointerToElements { p in
      for i in isOccupied.indices {
        if isOccupied[i] { (p + i).deinitialize(count: 1) }
      }
    }
  }

  var isOccupied: BitVector {
    set { header.isOccupied = newValue }
    _modify { yield &header.isOccupied }
    _read { yield header.isOccupied }
  }

  var fastCapacity: Int {
    set { header.capacity = newValue }
    _modify { yield &header.capacity }
    _read { yield header.capacity }
  }

  func clone(minimumCapacity: Int? = nil) -> Self {
    let minimumCapacity = minimumCapacity ?? isOccupied.count
    let r = Self.makeUninitialized(minimumCapacity: minimumCapacity, isOccupied: isOccupied)

    self.withUnsafeMutablePointerToElements { source in
      r.withUnsafeMutablePointerToElements { target in
        for i in isOccupied.indices {
          if isOccupied[i] { (target + i).initialize(to: source[i]) }
        }
      }
    }
    r.isOccupied.reserveCapacity(minimumCapacity)

    return r
  }

  static func makeUninitialized(minimumCapacity: Int, isOccupied: BitVector) -> Self {
    Self.create(minimumCapacity: minimumCapacity) { (r: ManagedBuffer)->Header in
      let capacity: Int
      if #available(OpenBSD 0.0, *) { capacity = minimumCapacity }
      else { capacity = r.capacity }
      return Header(
        isOccupied: isOccupied, capacity: capacity)
    } as! Self 
  }
}

private let emptyBuffer: Buffer<Void> = {
  let r = Buffer<Void>.makeUninitialized(minimumCapacity: 0, isOccupied: .init())
  r.fastCapacity = 0 // make sure we don't try to grow it.
  return r
}()

public struct ArrayOfOptional<T>: RandomAccessCollection, MutableCollection {
  private var storage: Buffer<T>

  public var startIndex: Int { 0 }
  public var endIndex: Int { isOccupied.count }

  public typealias Index = Int

  private var isOccupied: BitVector {
    _read { yield storage.header.isOccupied }
    _modify {
      assert(isKnownUniquelyReferenced(&storage))
      yield &storage.header.isOccupied
    }
  }

  public init() {
//    storage = .makeUninitialized(minimumCapacity: 0, isOccupied: .init())
    storage = unsafeBitCast(emptyBuffer, to: Buffer<T>.self)
  }

  public subscript(i: Index) -> T? {
    get {
      if !isOccupied[i] { return nil }
      return storage.withUnsafeMutablePointerToElements { p in p[i] }
    }
    set {
      if isKnownUniquelyReferenced(&storage) {
        self.setElementFast(at: i, to: newValue)
        return
      }
      self = self.settingElement(at: i, to: newValue)
    }
    _modify {
      let wasNonNil = isOccupied[i]

      if !isKnownUniquelyReferenced(&storage) { storage = storage.clone() }

      var projectedValue: T? = wasNonNil
        ? storage.withUnsafeMutablePointerToElements { p in (p + i).move() }
        : nil

      yield &projectedValue
      setElementFast(at: i, to: projectedValue)
    }
  }

  public var capacity: Int {
    get { Swift.min(bufferCapacity, isOccupied.capacity) }
  }

  private var bufferCapacity: Int {
    _read { yield storage.header.capacity }
  }

  public mutating func reserveCapacity(_ newCapacity: Int) {
    if bufferCapacity < newCapacity {
      storage = storage.clone(minimumCapacity: newCapacity)
    }
  }

  @inline(__always)
  private mutating func setElementFast(at i: Int, to newValue: T?) {
    if (newValue != nil) != isOccupied[i] {
      isOccupied[i].toggle()
    }

    storage.withUnsafeMutablePointerToElements { p in
      let q = p + i
      switch (newValue, isOccupied[i]) {
      case (nil, false): break
      case (nil, true): q.deinitialize(count: 1)
      case (_, true):   q.pointee = newValue.unsafelyUnwrapped
      case (_, false):  q.initialize(to: newValue.unsafelyUnwrapped)
      }
    }
  }

  @inline(never)
  private func settingElement(at i: Index, to newValue: T?) -> Self {
    var r = self
    r.storage = storage.clone()
    r.setElementFast(at: i, to: newValue)
    return r
  }

  public mutating func append(_ x: T?) {
    if count == bufferCapacity || !isKnownUniquelyReferenced(&storage)  {
      storage = storage.clone(
        minimumCapacity: count == bufferCapacity ? 2 * bufferCapacity : capacity)
    }
    if x != nil {
      storage.withUnsafeMutablePointerToElements { p in
        (p + count).initialize(to: x.unsafelyUnwrapped)
      }
    }
    isOccupied.append(x != nil)
  }

  public init<S: Sequence>(_ s: S) where S.Element == T? {
    self.init()
    self.reserveCapacity(s.underestimatedCount)
    for x in s { self.append(x) }
  }
}

extension ArrayOfOptional: Equatable where T: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool { lhs.elementsEqual(rhs) }
}

// Local Variables:
// fill-column: 100
// End:

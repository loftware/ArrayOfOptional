import LoftDataStructures_BitVector

/// Storage header for ArrayOfOptional buffers
private struct Header {
  /// Indication of whether each cell in the buffer is occupied, representing a non-nil T?.
  var isOccupied: BitVector

  /// Capacity of T storage allocated to the buffer.
  var capacity: Int
}

// FIXME: This is suboptimal; there should be one buffer for the bits and the
// Ts, all stored inline.

/// Shared buffer type for ArrayOfOptional.
private final class Buffer<T>: ManagedBuffer<Header, T> {
  deinit {
    withUnsafeMutablePointerToElements { p in
      for i in isOccupied.indices {
        if isOccupied[i] { (p + i).deinitialize(count: 1) }
      }
    }
  }

  /// Indication of whether each cell in `self` is occupied, representing a non-nil T?.
  var isOccupied: BitVector {
    set { header.isOccupied = newValue }
    _modify { yield &header.isOccupied }
    _read { yield header.isOccupied }
  }

  /// Returns a new instance of self with the same contents and storage for at
  /// least `minimumCapacity ?? isOccupied.count` elements.
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

  /// Returns a new instance of self with the given `isOccupied` value but no
  /// initialized `T` instances.
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

/// A RandomAccessCollection of `T?`, efficiently stored to avoid fragmentation.
public struct ArrayOfOptional<T>: RandomAccessCollection, MutableCollection {
  private var storage: Buffer<T>

  /// The position of the first element in `self`, or `endIndex` if there is no
  /// such element.
  public var startIndex: Int { 0 }

  /// The position one past the last element in `self`.
  public var endIndex: Int { isOccupied.count }

  /// A position in self.
  public typealias Index = Int

  /// An collection whose elements are `true` iff the corresponding element of `self` is non-`nil`.
  private var isOccupied: BitVector {
    _read { yield storage.header.isOccupied }
    _modify {
      assert(isKnownUniquelyReferenced(&storage))
      yield &storage.header.isOccupied
    }
  }

  /// Creates an empty instance
  public init() {
    storage = .makeUninitialized(minimumCapacity: 0, isOccupied: .init())
  }

  /// Accesses the `i`th element.
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

  /// The number of elements that `self` can store without reallocation.
  public var capacity: Int {
    get { Swift.min(bufferCapacity, isOccupied.capacity) }
  }

  /// The number of Ts storable directly in `storage`.
  private var bufferCapacity: Int {
    _read { yield storage.header.capacity }
  }

  /// Ensures that `self` can store at least `newCapacity` elements without
  /// reallocation.
  public mutating func reserveCapacity(_ newCapacity: Int) {
    if bufferCapacity < newCapacity {
      storage = storage.clone(minimumCapacity: newCapacity)
    }
    isOccupied.reserveCapacity(newCapacity)
  }

  /// Sets the `i`th element of `self` to `newValue`.
  ///
  /// - Precondition: `isKnownUniquelyReferenced(&storage)`.
  @inline(__always)
  private mutating func setElementFast(at i: Int, to newValue: T?) {
    assert(isKnownUniquelyReferenced(&storage))
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

  /// Returns a copy of `self` having element `i` set to `newValue`.
  @inline(never)
  private func settingElement(at i: Index, to newValue: T?) -> Self {
    var r = self
    r.storage = storage.clone()
    r.setElementFast(at: i, to: newValue)
    return r
  }

  /// Appends `x` to self.
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

  /// Creates a logical copy of the elements in `s`.
  public init<S: Sequence>(_ s: S) where S.Element == T? {
    self.init()
    self.reserveCapacity(s.underestimatedCount)
    for x in s { self.append(x) }
  }
}

extension ArrayOfOptional: Equatable where T: Equatable {
  /// Returns `true` iff `lhs` and `rhs` have equal elements.
  public static func == (lhs: Self, rhs: Self) -> Bool { lhs.elementsEqual(rhs) }
}

// Local Variables:
// fill-column: 100
// End:

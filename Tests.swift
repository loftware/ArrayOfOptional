import XCTest
import LoftDataStructures_ArrayOfOptional
import LoftTest_StandardLibraryProtocolChecks

extension Equatable {
  public func checkNotEqual(_ b: Self) {
    XCTAssertNotEqual(self, b)
    XCTAssertNotEqual(b, self)
  }
}

final class ArrayOfOptionalTests: XCTestCase {
  func testEmpty() {
    var x = ArrayOfOptional<Int>()
    x.checkBidirectionalCollectionLaws(expecting: EmptyCollection())
    x.checkMutableCollectionLaws(expecting: EmptyCollection(), writing: EmptyCollection())
    x.append(nil)
    XCTAssertEqual(x.count, 1)
    XCTAssertNil(x[0])
    x.checkNotEqual(.init())

    x = ArrayOfOptional<Int>()
    x.append(42)
    XCTAssertEqual(x.count, 1)
    XCTAssertEqual(x[0], 42)
    x.checkEquatableLaws()
    x.checkNotEqual(.init())
  }

  func test1() {
    var x = ArrayOfOptional<Int>(CollectionOfOne(nil))
    x.checkBidirectionalCollectionLaws(expecting: CollectionOfOne(nil))
    x.checkMutableCollectionLaws(expecting: CollectionOfOne(nil), writing: CollectionOfOne(42))
    x.append(nil)
    XCTAssertEqual(x.count, 2)
    XCTAssertEqual(x[0], nil)
    x.checkEquatableLaws()
    x.checkNotEqual(ArrayOfOptional<Int>())
    x.checkNotEqual(ArrayOfOptional<Int>(CollectionOfOne(42)))

    x = ArrayOfOptional<Int>()
    x.append(42)
    x.checkEquatableLaws()
    XCTAssertEqual(x.count, 1)
    XCTAssertEqual(x[0], 42)
    x.checkNotEqual(ArrayOfOptional<Int>(CollectionOfOne(nil)))
  }

  func test2() {
    var x = ArrayOfOptional<Int>([nil, nil])
    x.checkBidirectionalCollectionLaws(expecting: [nil, nil])
    x.checkMutableCollectionLaws(expecting: [nil, nil], writing: [42, 42])
    x.checkEquatableLaws()
    x.checkNotEqual(ArrayOfOptional<Int>())
    x.checkNotEqual(ArrayOfOptional<Int>([nil]))
    x.checkNotEqual(ArrayOfOptional<Int>([42]))
    x.checkNotEqual(ArrayOfOptional<Int>([42, 42]))

    x = ArrayOfOptional<Int>([nil, 42])
    x.checkBidirectionalCollectionLaws(expecting: [nil, 42])
    x.checkMutableCollectionLaws(expecting: [nil, 42], writing: [42, nil])

    x = ArrayOfOptional<Int>([42, nil])
    x.checkBidirectionalCollectionLaws(expecting: [42, nil])
    x.checkMutableCollectionLaws(expecting: [42, nil], writing: [nil, 42])

    x = ArrayOfOptional<Int>([42, 42])
    x.checkBidirectionalCollectionLaws(expecting: [42, 42])
    x.checkMutableCollectionLaws(expecting: [42, 42], writing: [nil, nil])
  }

  static let nonRepeating = (0..<30).lazy.map { $0 % 5 == 0 ? nil : Optional($0) }

  func testMany() {
    var x = ArrayOfOptional<Int>(Self.nonRepeating)
    x.checkBidirectionalCollectionLaws(expecting: Self.nonRepeating)
    x.checkMutableCollectionLaws(
      expecting: Self.nonRepeating, writing: Self.nonRepeating.lazy.map { $0.map { -$0 } ?? 99 })
  }

  func testAppend() {
    var x = ArrayOfOptional<Int>()
    x.append(nil)
    XCTAssertEqual(x.count, 1)
    XCTAssertEqual(x[0], nil)

    x.append(42)
    XCTAssertEqual(x.count, 2)
    XCTAssertEqual(x[0], nil)
    XCTAssertEqual(x[1], 42)

    x = ArrayOfOptional<Int>()
    for i in Self.nonRepeating.indices {
      x.append(Self.nonRepeating[i])
      XCTAssert(x.elementsEqual(Self.nonRepeating[...i]))
    }
  }

  func testEquatable() {
    var x = ArrayOfOptional<Int>(Self.nonRepeating)
    x.checkEquatableLaws()
    var y = x

    y.append(42)
    x.checkNotEqual(y)

    x.append(nil)
    x.checkNotEqual(y)
  }
}

// Local Variables:
// fill-column: 100
// End:

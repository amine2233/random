import Foundation // Only needed for SecRandomCopyBytes, used for random seed generation in the init() of RandomGenerator

// MARK: - RandomGenerator Protocol
// https://forums.swift.org/t/arc4random-uniform-on-linux-is-missing-from-foundation/5981/7
/// A pseudo random UInt64 bit pattern generator.
///
/// The generated UInt64 values can be converted to other types, for example:
///
///     // An instance of the Xoroshiro128Plus random generator:
///     let prng = Xoroshiro128Plus(seed: 1234)
///
///     // A uniformly distributed random Int in the range [1, 6]:
///     let roll = prng.next().int(inRange: 1 ... 6)
///
///     // A uniformly distributed random Double in the range [0, 1):
///     let d = prng.next().doubleInUnitRange()
///
///     // A uniformly distributed random array element:
///     let randomElement = someCollection.randomElement(using: prng)
///
///     // A single random UInt64 value can produce two Floats:
///     let (a, b) = prng.next().floatsInUnitRange()
///
///     // You can save computation time like this:
///     let rndBits = prng.next()
///     let roll = rndBits.int(inRange: 1 ... 6)
///     let d = rndBits.doubleInUnitRange()
///     let randomElement = someCollection.randomElement(using: rndBits)
///     let (a, b) = rndBits.floatsInUnitRange()
///
/// A random generator only have to implement two initializers and the
/// next() -> UInt64 method.
public protocol RandomGenerator : class {

    associatedtype State

    /// The current state of the random generator.
    var state: State { get }

    /// Creates a a new random generator with the given state.
    /// The initializer fails if the given state is invalid according to the random generator.
    init?(state: State)

    /// Creates a a new random generator with a state that is determined by `seed`.
    /// Each `seed` must result in a unique valid state.
    init(seed: UInt64)

    /// Returns the next random bit pattern and advances the state of the random generator.
    func next() -> UInt64
}

public extension RandomGenerator {
    /// Creates a a new random generator with a random state.
    /// This initializer calls self.init(seed: rs) where rs is produced using SecRandomCopyBytes.
    init() {
        var seed: UInt64 = 0
        // The following can be replaced by any other code that produces a random seed:
        #if os(macOS)
        withUnsafeMutablePointer(to: &seed) { uint64Ptr in
            let bytePtr = UnsafeMutableRawPointer(uint64Ptr).assumingMemoryBound(to: UInt8.self)
            precondition(SecRandomCopyBytes(kSecRandomDefault, 8, bytePtr) == 0)
        }
        #endif
        self.init(seed: seed)
    }
}

// MARK: - Two Random Generators

public final class SplitMix64 : RandomGenerator {
    // Based on http://xorshift.di.unimi.it/splitmix64.c
    // (Used in Xoroshiro128Plus to scramble its seed.)
    public var state: UInt64 // The state of SplitMix64 can be seeded with any value.

    public init(state: UInt64) { self.state = state }

    public init(seed: UInt64) { self.state = seed }

    public func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

public final class Xoroshiro128Plus : RandomGenerator {
    // Based on http://xoroshiro.di.unimi.it/xoroshiro128plus.c
    // Both higher quality and faster than SplitMix64, uses SplitMix64 to scramble seed into a valid state.
    public var state: (UInt64, UInt64) // The state of Xoroshiro128Plus must not be everywhere zero.

    public init?(state: (UInt64, UInt64)) {
        if state.0 != 0 || state.1 != 0 { self.state = state } else { return nil }
    }

    public init(seed: UInt64) { let sm = SplitMix64(seed: seed); state = (sm.next(), sm.next()) }

    public func next() -> UInt64 {
        func rol55(_ x: UInt64) -> UInt64 { return (x << 55) | (x >> 9) }
        func rol36(_ x: UInt64) -> UInt64 { return (x << 36) | (x >> 28) }
        let result = state.0 &+ state.1
        let t = state.1 ^ state.0
        state = (rol55(state.0) ^ t ^ (t << 14), rol36(t))
        return result
    }
}

// MARK: - UInt64 extensions for converting to other types

public extension UInt64 {
    func doubleInUnitRange() -> Double {
        let shifts: UInt64 = 63 - UInt64(Double.significandBitCount)
        return Double(self >> shifts) * (.ulpOfOne/2)
    }

    func floatsInUnitRange() -> (Float, Float) {
        let low = UInt32(self)
        let high = UInt32(self >> 32)
        let shifts: UInt32 = 31 - UInt32(Float.significandBitCount)
        return (
            Float(low >> shifts) * (.ulpOfOne/2),
            Float(high >> shifts) * (.ulpOfOne/2)
        )
    }

    func floatInUnitRange() -> Float {
        return floatsInUnitRange().0
    }

    func double(inRange range: Range<Double>) -> Double {
        return range.lowerBound + self.doubleInUnitRange() * (range.upperBound - range.lowerBound)
    }

    func int(inRange range: CountableRange<Int>) -> Int {
        let doubleRange = Range<Double>(
            uncheckedBounds: (
                Double(range.lowerBound),
                Double(range.upperBound)
            )
        )
        return Int(self.double(inRange: doubleRange).rounded(.down))
    }

    func int(inRange range: CountableClosedRange<Int>) -> Int {
        let doubleRange = Range<Double>(
            uncheckedBounds: (
                Double(range.lowerBound),
                Double(range.upperBound) + 1.0
            )
        )
        return Int(self.double(inRange: doubleRange).rounded(.down))
    }

    var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) {
        return unsafeBitCast(self, to: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8).self)
    }
}

// MARK: - Collection extensions for shuffling and getting random elements

public extension Collection where Index == Int {
    func randomElement<R: RandomGenerator>(using randomGenerator: R) -> Iterator.Element {
        return self[randomGenerator.next().int(inRange: 0 ..< count)]
    }

    func randomElement(using randomBits: UInt64) -> Iterator.Element {
        return self[randomBits.int(inRange: 0 ..< count)]
    }

    mutating func shuffled<R: RandomGenerator>(using randomGenerator: R) -> [Iterator.Element] {
        var mutableCopy = Array<Iterator.Element>(self)
        mutableCopy.shuffle(using: randomGenerator)
        return mutableCopy
    }

}

public extension MutableCollection where Index == Int {
    mutating func shuffle<R: RandomGenerator>(using randomGenerator: R) {
        if count < 2 { return }
        for i1 in (1 ..< count).reversed() {
            let i2 = randomGenerator.next().int(inRange: 0 ..< i1+1)
            (self[i1], self[i2]) = (self[i2], self[i1])
        }
    }
}

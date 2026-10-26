public import AemiProtobuf

/// A flat message of 100 `int32` fields, to see whether decoding cost grows with the number of fields a message declares.
@ProtoMessage
public struct Wide100: Equatable {
    @ProtoField(1) public var f1: Int32 = 0
    @ProtoField(2) public var f2: Int32 = 0
    @ProtoField(3) public var f3: Int32 = 0
    @ProtoField(4) public var f4: Int32 = 0
    @ProtoField(5) public var f5: Int32 = 0
    @ProtoField(6) public var f6: Int32 = 0
    @ProtoField(7) public var f7: Int32 = 0
    @ProtoField(8) public var f8: Int32 = 0
    @ProtoField(9) public var f9: Int32 = 0
    @ProtoField(10) public var f10: Int32 = 0
    @ProtoField(11) public var f11: Int32 = 0
    @ProtoField(12) public var f12: Int32 = 0
    @ProtoField(13) public var f13: Int32 = 0
    @ProtoField(14) public var f14: Int32 = 0
    @ProtoField(15) public var f15: Int32 = 0
    @ProtoField(16) public var f16: Int32 = 0
    @ProtoField(17) public var f17: Int32 = 0
    @ProtoField(18) public var f18: Int32 = 0
    @ProtoField(19) public var f19: Int32 = 0
    @ProtoField(20) public var f20: Int32 = 0
    @ProtoField(21) public var f21: Int32 = 0
    @ProtoField(22) public var f22: Int32 = 0
    @ProtoField(23) public var f23: Int32 = 0
    @ProtoField(24) public var f24: Int32 = 0
    @ProtoField(25) public var f25: Int32 = 0
    @ProtoField(26) public var f26: Int32 = 0
    @ProtoField(27) public var f27: Int32 = 0
    @ProtoField(28) public var f28: Int32 = 0
    @ProtoField(29) public var f29: Int32 = 0
    @ProtoField(30) public var f30: Int32 = 0
    @ProtoField(31) public var f31: Int32 = 0
    @ProtoField(32) public var f32: Int32 = 0
    @ProtoField(33) public var f33: Int32 = 0
    @ProtoField(34) public var f34: Int32 = 0
    @ProtoField(35) public var f35: Int32 = 0
    @ProtoField(36) public var f36: Int32 = 0
    @ProtoField(37) public var f37: Int32 = 0
    @ProtoField(38) public var f38: Int32 = 0
    @ProtoField(39) public var f39: Int32 = 0
    @ProtoField(40) public var f40: Int32 = 0
    @ProtoField(41) public var f41: Int32 = 0
    @ProtoField(42) public var f42: Int32 = 0
    @ProtoField(43) public var f43: Int32 = 0
    @ProtoField(44) public var f44: Int32 = 0
    @ProtoField(45) public var f45: Int32 = 0
    @ProtoField(46) public var f46: Int32 = 0
    @ProtoField(47) public var f47: Int32 = 0
    @ProtoField(48) public var f48: Int32 = 0
    @ProtoField(49) public var f49: Int32 = 0
    @ProtoField(50) public var f50: Int32 = 0
    @ProtoField(51) public var f51: Int32 = 0
    @ProtoField(52) public var f52: Int32 = 0
    @ProtoField(53) public var f53: Int32 = 0
    @ProtoField(54) public var f54: Int32 = 0
    @ProtoField(55) public var f55: Int32 = 0
    @ProtoField(56) public var f56: Int32 = 0
    @ProtoField(57) public var f57: Int32 = 0
    @ProtoField(58) public var f58: Int32 = 0
    @ProtoField(59) public var f59: Int32 = 0
    @ProtoField(60) public var f60: Int32 = 0
    @ProtoField(61) public var f61: Int32 = 0
    @ProtoField(62) public var f62: Int32 = 0
    @ProtoField(63) public var f63: Int32 = 0
    @ProtoField(64) public var f64: Int32 = 0
    @ProtoField(65) public var f65: Int32 = 0
    @ProtoField(66) public var f66: Int32 = 0
    @ProtoField(67) public var f67: Int32 = 0
    @ProtoField(68) public var f68: Int32 = 0
    @ProtoField(69) public var f69: Int32 = 0
    @ProtoField(70) public var f70: Int32 = 0
    @ProtoField(71) public var f71: Int32 = 0
    @ProtoField(72) public var f72: Int32 = 0
    @ProtoField(73) public var f73: Int32 = 0
    @ProtoField(74) public var f74: Int32 = 0
    @ProtoField(75) public var f75: Int32 = 0
    @ProtoField(76) public var f76: Int32 = 0
    @ProtoField(77) public var f77: Int32 = 0
    @ProtoField(78) public var f78: Int32 = 0
    @ProtoField(79) public var f79: Int32 = 0
    @ProtoField(80) public var f80: Int32 = 0
    @ProtoField(81) public var f81: Int32 = 0
    @ProtoField(82) public var f82: Int32 = 0
    @ProtoField(83) public var f83: Int32 = 0
    @ProtoField(84) public var f84: Int32 = 0
    @ProtoField(85) public var f85: Int32 = 0
    @ProtoField(86) public var f86: Int32 = 0
    @ProtoField(87) public var f87: Int32 = 0
    @ProtoField(88) public var f88: Int32 = 0
    @ProtoField(89) public var f89: Int32 = 0
    @ProtoField(90) public var f90: Int32 = 0
    @ProtoField(91) public var f91: Int32 = 0
    @ProtoField(92) public var f92: Int32 = 0
    @ProtoField(93) public var f93: Int32 = 0
    @ProtoField(94) public var f94: Int32 = 0
    @ProtoField(95) public var f95: Int32 = 0
    @ProtoField(96) public var f96: Int32 = 0
    @ProtoField(97) public var f97: Int32 = 0
    @ProtoField(98) public var f98: Int32 = 0
    @ProtoField(99) public var f99: Int32 = 0
    @ProtoField(100) public var f100: Int32 = 0
}

extension Wide100 {
    /// Every field set, so every field is written and read.
    public static var filled: Wide100 {
        Wide100(
            f1: Int32(1), f2: Int32(2), f3: Int32(3), f4: Int32(4), f5: Int32(5), f6: Int32(6), f7: Int32(7),
            f8: Int32(8), f9: Int32(9), f10: Int32(10), f11: Int32(11), f12: Int32(12), f13: Int32(13), f14: Int32(14),
            f15: Int32(15), f16: Int32(16), f17: Int32(17), f18: Int32(18), f19: Int32(19), f20: Int32(20),
            f21: Int32(21), f22: Int32(22), f23: Int32(23), f24: Int32(24), f25: Int32(25), f26: Int32(26),
            f27: Int32(27), f28: Int32(28), f29: Int32(29), f30: Int32(30), f31: Int32(31), f32: Int32(32),
            f33: Int32(33), f34: Int32(34), f35: Int32(35), f36: Int32(36), f37: Int32(37), f38: Int32(38),
            f39: Int32(39), f40: Int32(40), f41: Int32(41), f42: Int32(42), f43: Int32(43), f44: Int32(44),
            f45: Int32(45), f46: Int32(46), f47: Int32(47), f48: Int32(48), f49: Int32(49), f50: Int32(50),
            f51: Int32(51), f52: Int32(52), f53: Int32(53), f54: Int32(54), f55: Int32(55), f56: Int32(56),
            f57: Int32(57), f58: Int32(58), f59: Int32(59), f60: Int32(60), f61: Int32(61), f62: Int32(62),
            f63: Int32(63), f64: Int32(64), f65: Int32(65), f66: Int32(66), f67: Int32(67), f68: Int32(68),
            f69: Int32(69), f70: Int32(70), f71: Int32(71), f72: Int32(72), f73: Int32(73), f74: Int32(74),
            f75: Int32(75), f76: Int32(76), f77: Int32(77), f78: Int32(78), f79: Int32(79), f80: Int32(80),
            f81: Int32(81), f82: Int32(82), f83: Int32(83), f84: Int32(84), f85: Int32(85), f86: Int32(86),
            f87: Int32(87), f88: Int32(88), f89: Int32(89), f90: Int32(90), f91: Int32(91), f92: Int32(92),
            f93: Int32(93), f94: Int32(94), f95: Int32(95), f96: Int32(96), f97: Int32(97), f98: Int32(98),
            f99: Int32(99), f100: Int32(100))
    }
}

import Foundation

class Mqtt
{
    public static let ControlPacketTypeConnect    = 0b0001_0000
    public static let ControlPacketTypeConnAck    = 0b0010_0000
    public static let ControlPacketTypeSubscribe  = 0b1000_0010
    public static let ControlPacketTypeSubAck     = 0b1001_0000
    public static let ControlPacketTypeDisconnect = 0b1110_0000

    public static let ControlPacketIdentifierPublish = 0b0011_0000

    public static let ProtocolName    = "MQTT"
    public static let ProtocolVersion = 0b0000_0101

    public static let ConnectFlagCleanStart  = 0b0000_0010
    public static let ConnectFlagUseUserName = 0b1000_0000
    public static let ConnectFlagUsePassword = 0b0100_0000

    public static let VariableIntegerMaxSize = 0xFFFF_FF7F
    public static let Utf8StringMaxByteSize  = 0b1111_1111_1111_1111

    public static let VariableByteIntegerContinuationBit = 0b1000_0000
    public static let VariableByteIntegerValueBits       = 0b0111_1111

    public static let ClientIdValidChars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    public static let ClientIdMaxLength  = 23

    public static let DisconnectionReasonCodeNormal = 0b0000_0000
}

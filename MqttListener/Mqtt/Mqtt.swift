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
}

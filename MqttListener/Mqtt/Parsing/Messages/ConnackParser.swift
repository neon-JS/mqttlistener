import Foundation

class ConnackParser : MessageParser
{
    private let fixedHeaderParser: FixedHeaderParser
    private let remainingLengthParser: RemainingLengthParser
    private let connackFlagParser: ByteValueParser
    private let reasonCodeParser: ReasonCodeParser
    private let propertiesParser: PropertiesParser

    public init(
        _ fixedHeaderParser: FixedHeaderParser,
        _ remainingLengthParser: RemainingLengthParser,
        _ connackFlagParser: ByteValueParser,
        _ reasonCodeParser: ReasonCodeParser,
        _ propertiesParser: PropertiesParser
    ) {
        self.fixedHeaderParser = fixedHeaderParser
        self.remainingLengthParser = remainingLengthParser
        self.connackFlagParser = connackFlagParser
        self.reasonCodeParser = reasonCodeParser
        self.propertiesParser = propertiesParser
    }

    public func parse(message: MessageData) throws -> Message
    {
        /*
            0b0010_0000 // Type CONNACK
            0bXXXX_XXXX // Remaining length

            0b0000_000X // CONNACK Flags. If 0b0000_0001 -> resumed session, otherwise clean session. All other bits (0b0000_000X) are reserved!

            0bXXXX_XXXX // Status Code ("Reason Code") -> Status

            0b0000_0011 // Properties length

            0b0001_0010 // 34 -> Topic alias maximum: Next to bytes showing max topics
            0b0000_0000 // 0 (MSB)
            0b0000_1001 // 10 (LSB)
         */

        let (fixedHeader, remainingLengthOffset) = try self.fixedHeaderParser.extractPart(messageData: message, offset: 0)
        let (remainingLength, connackFlagOffset) = try self.remainingLengthParser.extractPart(messageData: message, offset: remainingLengthOffset)
        let (connackFlags, reasonCodeOffset) = try self.connackFlagParser.extractPart(messageData: message, offset: connackFlagOffset)
        let (reasonCode, propertiesOffset) = try self.reasonCodeParser.extractPart(messageData: message, offset: reasonCodeOffset)
        let (properties, _) = try self.propertiesParser.extractPart(messageData: message, offset: propertiesOffset)

        return Message(
            fixedHeader: fixedHeader,
            remainingLength: remainingLength,
            topicName: nil,
            packetIdentifier: nil,
            properties: properties,
            payload: nil,
            reasonCode: reasonCode,
            connackFlags: connackFlags
        )
    }
}

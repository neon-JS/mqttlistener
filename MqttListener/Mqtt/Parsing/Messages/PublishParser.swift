import Foundation

class PublishParser : MessageParser
{
    private let fixedHeaderParser: FixedHeaderParser
    private let remainingLengthParser: RemainingLengthParser
    private let topicNameParser: TopicNameParser
    private let packetIdentifierParser: PacketIdentifierParser
    private let propertiesParser: PropertiesParser
    private let payloadParser: PayloadParser

    public init(
        _ fixedHeaderParser: FixedHeaderParser,
        _ remainingLengthParser: RemainingLengthParser,
        _ topicNameParser: TopicNameParser,
        _ packetIdentifierParser: PacketIdentifierParser,
        _ propertiesParser: PropertiesParser,
        _ payloadParser: PayloadParser
    ) {
        self.fixedHeaderParser = fixedHeaderParser
        self.remainingLengthParser = remainingLengthParser
        self.topicNameParser = topicNameParser
        self.packetIdentifierParser = packetIdentifierParser
        self.propertiesParser = propertiesParser
        self.payloadParser = payloadParser
    }

    public func parse(message: MessageData) throws -> Message
    {
        /*
            0b0011_DQQR // D = is duplicate (server -> client always 0), QQ = QoS, R = retain
            0bXXXX_XXXX // Remaining length

            0bXXXX_XXXX // Topic Name length (MSB)
            0bXXXX_XXXX // Topic Name length (LSB)
            0bXXXX_XXXX // Topic name
            ...

           (0bXXXX_XXXX) // Packet identifier MSB (QoS > 0)
           (0bXXXX_XXXX) // Packet identifier LSB (QoS > 0)

            0bXXXX_XXXX // Properties length

            0bXXXX_XXXX // Data!
            ...
         */

        let (fixedHeader, remainingLengthOffset) = try self.fixedHeaderParser.extractPart(messageData: message, offset: 0)
        let (remainingLength, topicNameOffset) = try self.remainingLengthParser.extractPart(messageData: message, offset: remainingLengthOffset)
        let (topicName, nextOffset) = try self.topicNameParser.extractPart(messageData: message, offset: topicNameOffset)

        let hasPacketIdentifier = fixedHeader & 0b0000_0110 != 0 // QoS > 0

        var propertiesOffset: Int
        var packetIdentifier: Int?

        if (hasPacketIdentifier) {
            (packetIdentifier, propertiesOffset) = try self.packetIdentifierParser.extractPart(messageData: message, offset: nextOffset)
        } else {
            propertiesOffset = nextOffset
            packetIdentifier = nil
        }

        let (properties, payloadOffset) = try self.propertiesParser.extractPart(messageData: message, offset: propertiesOffset)
        let (payload, _) = try self.payloadParser.extractPart(messageData: message, offset: payloadOffset)

        return Message(
            fixedHeader: fixedHeader,
            remainingLength: remainingLength,
            topicName: topicName,
            packetIdentifier: packetIdentifier,
            properties: properties,
            payload: payload,
            reasonCode: nil,
            connackFlags: nil
        )
    }
}

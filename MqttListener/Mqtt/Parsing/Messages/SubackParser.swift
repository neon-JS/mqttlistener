import Foundation

class SubackParser : MessageParser
{
    private let fixedHeaderParser: FixedHeaderParser
    private let remainingLengthParser: RemainingLengthParser
    private let packetIdentifierParser: PacketIdentifierParser
    private let propertiesParser: PropertiesParser
    private let payloadParser: PayloadParser

    public init(
        _ fixedHeaderParser: FixedHeaderParser,
        _ remainingLengthParser: RemainingLengthParser,
        _ packetIdentifierParser: PacketIdentifierParser,
        _ propertiesParser: PropertiesParser,
        _ payloadParser: PayloadParser
    ) {
        self.fixedHeaderParser = fixedHeaderParser
        self.remainingLengthParser = remainingLengthParser
        self.packetIdentifierParser = packetIdentifierParser
        self.propertiesParser = propertiesParser
        self.payloadParser = payloadParser
    }

    public func parse(message: MessageData) throws -> Message
    {
        /*
            0b1001_0000 // SUBACK
            0bXXXX_XXXX // Remaining length

            0bXXXX_XXXX // Packet identifier from SUBSCRIBE request (MSB)
            0bXXXX_XXXX // Packet identifier from SUBSCRIBE request (LSB)

            0bXXXX_XXXX // Properties length
            ...

            0b0000_0000 // Payload
         */
        let (fixedHeader, remainingLengthOffset) = try self.fixedHeaderParser.extractPart(messageData: message, offset: 0)
        let (remainingLength, packetIdentifierOffset) = try self.remainingLengthParser.extractPart(messageData: message, offset: remainingLengthOffset)
        let (packetIdentifier, propertiesOffset) = try self.packetIdentifierParser.extractPart(messageData: message, offset: packetIdentifierOffset)
        let (properties, payloadOffset) = try self.propertiesParser.extractPart(messageData: message, offset: propertiesOffset)
        let (payload, _) = try self.payloadParser.extractPart(messageData: message, offset: payloadOffset)

        return Message(
            fixedHeader: fixedHeader,
            remainingLength: remainingLength,
            topicName: nil,
            packetIdentifier: packetIdentifier,
            properties: properties,
            payload: payload,
            reasonCode: nil,
            connackFlags: nil
        )
    }
}

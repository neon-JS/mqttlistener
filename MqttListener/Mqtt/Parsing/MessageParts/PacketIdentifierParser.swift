import Foundation

class PacketIdentifierParser : MessagePartParser
{
    typealias T = Int

    public func extractPart(messageData: MessageData, offset: Int) throws -> (Int, Int)
    {
        if (messageData.count <= offset + 2) {
            throw MqttFormatError.invalidMessageData
        }

        let packetIdentifier = (messageData[offset] << 8) + (messageData[offset + 1] & 0b1111_1111)

        return (packetIdentifier, offset + 2)
    }
}

import Foundation

class ByteValueParser : MessagePartParser
{
    typealias T = Int

    public func extractPart(messageData: MessageData, offset: Int) throws -> (Int, Int)
    {
        if (messageData.count <= offset) {
            throw MqttFormatError.invalidMessageData
        }

        return (messageData[offset], offset + 1)
    }
}

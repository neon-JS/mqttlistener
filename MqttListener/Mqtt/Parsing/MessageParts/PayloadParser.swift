import Foundation

class PayloadParser : MessagePartParser
{
    typealias T = MessageData

    public func extractPart(messageData: MessageData, offset: Int) throws -> (MessageData, Int)
    {
        if (messageData.count <= offset) {
            throw MqttFormatError.invalidMessageData
        }

        let relevantData = Array(messageData[offset...])

        return (relevantData, offset + relevantData.count)
    }
}

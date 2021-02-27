import Foundation

class PropertiesParser : MessagePartParser
{
    typealias T = Properties

    private let integerEncoder: IntegerEncoder

    public init(_ integerEncoder: IntegerEncoder)
    {
        self.integerEncoder = integerEncoder
    }

    public func extractPart(messageData: MessageData, offset: Int) throws -> (Properties, Int)
    {
        if (messageData.count <= offset) {
            throw MqttFormatError.invalidMessageData
        }

        let relevantData = Array(messageData[offset...])
        let propertiesLength = try self.integerEncoder.decode(relevantData) + self.integerEncoder.getEncodedLength(relevantData)

        if (relevantData.count < propertiesLength) {
            throw MqttFormatError.invalidMessageData
        }

        // TODO
        return (Properties(), offset + propertiesLength)
    }
}

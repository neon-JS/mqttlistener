import Foundation

class TopicNameParser : MessagePartParser
{
    typealias T = String

    private let stringEncoder: StringEncoder

    public init(_ stringEncoder: StringEncoder)
    {
        self.stringEncoder = stringEncoder
    }

    public func extractPart(messageData: MessageData, offset: Int) throws -> (String, Int)
    {
        if (messageData.count <= offset) {
            throw MqttFormatError.invalidMessageData
        }

        let part = Array(messageData[offset...])
        let value = try self.stringEncoder.decode(part)
        let stringLength = try self.stringEncoder.getEncodedLength(part)

        return (value, offset + stringLength)
    }
}

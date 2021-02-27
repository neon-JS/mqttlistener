import Foundation

class RemainingLengthParser : MessagePartParser
{
    typealias T = Int

    private let integerEncoder: IntegerEncoder

    public init(_ integerEncoder: IntegerEncoder)
    {
        self.integerEncoder = integerEncoder
    }

    public func extractPart(messageData: MessageData, offset: Int) throws -> (Int, Int)
    {
        if (messageData.count <= offset) {
            throw MqttFormatError.invalidMessageData
        }

        let part = Array(messageData[offset...])

        let value = try self.integerEncoder.decode(part)
        let bytesLength = try self.integerEncoder.getEncodedLength(part)

        return (value, offset + bytesLength)
    }
}

import Foundation

class IntegerEncoder
{
    public static func encodeVariableByteInteger(_ value: Int) throws -> MessageData
    {
        if (value > Mqtt.VariableIntegerMaxSize) {
            throw MqttFormatError.variableIntegerOverflow
        }

        var bytes: [Int] = []
        var handledValue = value

        while handledValue > 0 {
            var leastSignificantByte = handledValue % Mqtt.VariableByteIntegerContinuationBit   // Get LSB (aka "the next seven bits")
            handledValue = handledValue >> 7                                                    // Remove LSB from value

            if (handledValue > 0) {
                // For every byte that is not the last one (because there's a value left)
                leastSignificantByte = leastSignificantByte | Mqtt.VariableByteIntegerContinuationBit
            }

            bytes.append(leastSignificantByte)
        }

        return bytes
    }

    public static func decodeVariableByteInteger(_ data: MessageData) throws -> Int
    {
        if (data.count > 4) {
            throw MqttFormatError.variableIntegerOverflow
        }

        var multiplier = 1
        var value = 0

        for byte in data {
            value += (byte & Mqtt.VariableByteIntegerValueBits) * multiplier
            multiplier *= 0b1000_0000
        }

        return value
    }
}

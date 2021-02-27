import Foundation

class IntegerEncoder : Encoder
{
    typealias T = Int

    public func encode(_ value: Int) throws -> MessageData
    {
        if (value > Mqtt.VariableIntegerMaxSize) {
            throw MqttFormatError.variableIntegerOverflow
        }

        var bytes: MessageData = []
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

    public func decode(_ data: MessageData) throws -> Int
    {
        var multiplier = 1
        var value = 0

        for (index, byte) in data.enumerated() {
            if (index > 3) {
                throw MqttFormatError.variableIntegerOverflow
            }

            value += (byte & Mqtt.VariableByteIntegerValueBits) * multiplier
            multiplier *= 0b1000_0000

            if(byte & Mqtt.VariableByteIntegerContinuationBit == 0)
            {
                break
            }
        }

        return value
    }

    public func getEncodedLength(_ data: MessageData) throws -> Int
    {
        for (index, byte) in data.enumerated() {
            if (byte & Mqtt.VariableByteIntegerContinuationBit == 0) {
                return index + 1
            }
        }

        throw MqttFormatError.invalidVariableIntegerData
    }
}

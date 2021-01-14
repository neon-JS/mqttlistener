import Foundation

enum MqttFormatError : Error {
    case variableIntegerOverflowError
}

class MqttFormatService
{
    public static func encodeVariableByteInteger(value: Int) throws -> [Int]
    {
        if (value > 0xFFFF_FF7F) {
            throw MqttFormatError.variableIntegerOverflowError
        }
        
        var bytes: [Int] = []
        var handledValue = value;
        
        while handledValue > 0 {
            var leastSignificantByte = handledValue % 0b1000_0000 // Get LSB
            handledValue = handledValue >> 7 // Remove LSB from value
            
            if (handledValue > 0) {
                // For every byte that is not the last one (because there's a value left)
                leastSignificantByte = leastSignificantByte | 0b1000_0000 // Add "continuation-bit"
            }
            
            bytes.append(leastSignificantByte)
        }

        return bytes
    }
    
    public static func decodeVariableByteInteger(values: [Int]) throws -> Int
    {
        if (values.count > 4) {
            throw MqttFormatError.variableIntegerOverflowError
        }
        
        var multiplier = 1
        var value = 0
        
        for byte in values {
            value += (byte & 0b0111_1111) * multiplier
            multiplier *= 0b1000_0000
        }
        
        return value
    }
    
    public static func encodeString(value: String) -> [Int]
    {
        let utf8string = value.utf8
        var bytes: [Int] = []
        
        bytes.append(utf8string.count >> 8) // Length MSB
        bytes.append(utf8string.count & 0b1111_1111) // Length LSB
        
        for char in utf8string {
            bytes.append(Int(char))
        }
        
        return bytes
    }
    
    public static func decodeString(bytes: [Int]) -> String
    {
        let chars = bytes[2..<bytes.count].map { (byte) -> Character in
            Character(UnicodeScalar(byte) ?? "?" as Unicode.Scalar)
        }
        
        return String(chars)
    }
    
    public static func dataToIntArray(data: Data) -> [Int]
    {
        return data.map { (value) -> Int in
            Int(value)
        }
    }
    
    public static func convertToData(values: [[Int]]) -> Data
    {
        var singleList: [UInt8] = values
            .reduce([]) { (list, current) -> [Int] in
                list + current
            }
            .map { (v) -> UInt8 in
                UInt8(v)
            }
        
        // Calculate correct length
        singleList[1] = UInt8(singleList.count - 2)
        
        return singleList.withUnsafeBytes { Data($0) }
    }
}
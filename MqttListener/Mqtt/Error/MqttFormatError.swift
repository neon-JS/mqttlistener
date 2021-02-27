import Foundation

enum MqttFormatError : Error
{
    case variableIntegerOverflow
    case stringMaxLengthExceeded
    case emptyTopic
}

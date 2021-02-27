import Foundation

enum MqttFormatError : Error
{
    case variableIntegerOverflow
    case stringMaxLengthExceeded
    case emptyTopic
    case invalidStringData
    case invalidVariableIntegerData
    case invalidMessageData
}

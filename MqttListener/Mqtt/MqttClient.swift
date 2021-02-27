import Foundation
import Network

class MqttClient
{
    private let client : Client
    private let clientId : String
    private let userName: String?
    private let password: String?

    private var onMessageHandler: ((String, Message) -> Void)?

    convenience init(client: Client, clientId: String)
    {
        self.init(client: client, clientId: clientId, userName: nil, password: nil)
    }

    init(client: Client, clientId: String, userName: String?, password: String?)
    {
        self.client = client
        self.clientId = clientId
        self.userName = userName
        self.password = password

        self.client.setOnDataHandler(self.onData)
    }

    public func setOnMessageHandler(_ handler: ((String, Message) -> Void)?)
    {
        self.onMessageHandler = handler
    }

    public func connect() throws
    {
        // Build connect flags
        var connectFlags = Mqtt.ConnectFlagCleanStart // Starting with a clean session. As this is just a plain listener, we won't use a will!

        if (self.userName != nil) {
            connectFlags |= Mqtt.ConnectFlagUseUserName
        }

        if (self.password != nil) {
            connectFlags |= Mqtt.ConnectFlagUsePassword
        }

        var parts: [MessageData] = [
            try StringEncoder.encodeString(Mqtt.ProtocolName),
            [
                Mqtt.ProtocolVersion,
                connectFlags,

                0b0000_0000, // Keepalive MSB,
                0b0000_0000, // Keepalive LSB

                0x0000_0000, // Property-length (0 as no properties are set) but necessary for MQTT5
            ],

            try StringEncoder.encodeString(self.clientId) // Begin of payload
        ]

        if (self.userName != nil) {
            try parts.append(StringEncoder.encodeString(self.userName!))
        }

        if (self.password != nil) {
            try parts.append(StringEncoder.encodeString(self.password!))
        }

        try self.client.send(MessageEncoder.encodeMessageFromParts(controlPacketType: Mqtt.ControlPacketTypeConnect, parts))
    }

    public func subscribe(topic: String) throws
    {
        if (topic.isEmpty) {
            throw MqttFormatError.emptyTopic
        }

        let subscriptionOptions = Mqtt.SubscribeOptionFlagQoS2 | Mqtt.SubscribeOptionNoLocale | Mqtt.SubscribeOptionRetainedMessageOnlyOnNewSubscription;

        let parts: [MessageData] = [
            [
                0b0000_0000, // Packet identifier (MSB). We use this to recognize the ACK later. We also choose the identifier ourselves!
                0b0000_1110, // Packet identifier (LSB)

                0b0000_0000, // Properties length. As we dont use them, its 0
            ],
            try StringEncoder.encodeString(topic),
            [
                subscriptionOptions,
            ]
        ]
        try self.client.send(MessageEncoder.encodeMessageFromParts(controlPacketType: Mqtt.ControlPacketTypeSubscribe, parts))
    }

    public func disconnect()
    {
        let data = Data([
            UInt8(Mqtt.ControlPacketTypeDisconnect),
            0b0000_0010, // Remaining length

            UInt8(Mqtt.DisconnectionReasonCodeNormal), // Reason code -> normal disconnection

            0b0000_0000, // Properties length (empty, therefore 0)
        ])

        try! self.client.send(data)
        try! self.client.disconnect()
    }

    public static func generateClientId() -> String
    {
        var clientId = "MqttListener"

        for _ in clientId.count..<Mqtt.ClientIdMaxLength {
            clientId.append(Mqtt.ClientIdValidChars.randomElement()!)
        }

        return clientId
    }

    private func onData(_ data: Data) -> Void
    {
        do {
            let convertedData = MqttClient.convertDataToMessageData(data)
            let messages = try MessageEncoder.extractMessagesFromData(convertedData)

            for message in messages {
                self.onMqttMessage(message)
            }
        } catch {
            DebugService.error("Error while handling incoming data: \(error)")
        }
    }

    private func onMqttMessage(_ message: Message)
    {
        if (message.count == 0) {
            DebugService.log("Discarding empty message!")
            return
        }

        let controlPacketIdentifier = message[0]

        if (controlPacketIdentifier == Mqtt.ControlPacketTypeConnAck) {
            self.handleConnAck(message)
        } else if (controlPacketIdentifier == Mqtt.ControlPacketTypeSubAck) {
            self.handleSubAck(message)
        } else if ((controlPacketIdentifier & Mqtt.ControlPacketIdentifierPublish) == Mqtt.ControlPacketIdentifierPublish) {
            self.handlePublish(message)
        } else {
            DebugService.log("Received unspecified message with \(message.count) bytes:")
            DebugService.printBinaryData(message)
        }
    }

    private func handleSubAck(_ data: Message)
    {
        /*
            0b1001_0000 // SUBACK
            0bXXXX_XXXX // Remaining length

            0bXXXX_XXXX // Packet identifier from SUBSCRIBE request (MSB)
            0bXXXX_XXXX // Packet identifier from SUBSCRIBE request (LSB)

            0bXXXX_XXXX // Properties length

            0bXXXX_XXXX // Payload
         */

        DebugService.log("Got SUBACK")

        if (data.count < 5) {
            DebugService.log("Discarding SUBACK as message seems to be malformed.")
            DebugService.printBinaryData(data)
            return
        }

        let statusPayloadIndex = try! MessageEncoder.getFirstDataByteIndex(data) // Offset by header and remaining length
            + 2 // Offset by packet identifier
            + IntegerEncoder.decodeVariableByteInteger(Array(data[4...])) // Properties length that we'll ignore
            + MessageEncoder.getEncodedIntegerLength(data[4...]) // Length of properties length itself

        if (data.count <= statusPayloadIndex) {
            DebugService.log("Discarding SUBACK as message seems to be malformed.")
            DebugService.printBinaryData(data)
            return
        }

        if (data[statusPayloadIndex] >= 0b1000_0000) {
            // Payload contains status-code. Every status-code >= 128 indicates an error.
            DebugService.error("Status code indicates an error during SUBACK. Code: \(data[statusPayloadIndex])")
        }
    }

    private func handleConnAck(_ data: Message)
    {
        /*
            0b0010_0000 // Type CONNACK
            0bXXXX_XXXX // Remaining length

            0b0000_000X // CONNACK Flags. If 0b0000_0001 -> resumed session, otherwise clean session. All other bits (0b0000_000X) are reserved!

            0bXXXX_XXXX // Status Code ("Reason Code") -> Status

            0b0000_0011 // Properties length

            0b0001_0010 // 34 -> Topic alias maximum: Next to bytes showing max topics
            0b0000_0000 // 0 (MSB)
            0b0000_1001 // 10 (LSB)
         */

        DebugService.log("Got CONNACK")

        let connackFlagIndex = try! MessageEncoder.getFirstDataByteIndex(data)
        let reasonCodeIndex = connackFlagIndex + 1;

        if (data.count <= reasonCodeIndex) {
            DebugService.log("Discarding CONNACK as message seems to be malformed.")
            DebugService.printBinaryData(data)
            return
        }

        if (data[reasonCodeIndex] != Mqtt.ConnackReasonCodeSuccess) {
            DebugService.error("Status code indicates an error during CONNACK. Code: \(data[reasonCodeIndex])")
            return
        }

        if (data[connackFlagIndex] == Mqtt.ConnackFlagSessionPresent) {
            DebugService.log("Using present session during CONNACK")
        }
    }

    private func handlePublish(_ data: Message)
    {
        /*
            0b0011_DQQR // D = is duplicate (server -> client always 0), QQ = QoS, R = retain
            0bXXXX_XXXX // Remaining length

            0bXXXX_XXXX // Topic Name length (MSB)
            0bXXXX_XXXX // Topic Name length (LSB)
            0bXXXX_XXXX // Topic name
            ...

           (0bXXXX_XXXX) // Packet identifier MSB (QoS > 0)
           (0bXXXX_XXXX) // Packet identifier LSB (QoS > 0)

            0bXXXX_XXXX // Properties length

            0bXXXX_XXXX // Data!
            ...
         */

        DebugService.log("Got PUBLISH")

        let topicLengthIndex = try! MessageEncoder.getFirstDataByteIndex(data);

        if (data.count <= topicLengthIndex + 1) {
            DebugService.log("Discarding PUBLISH as message seems to be malformed.")
            DebugService.printBinaryData(data)
            return
        }

        var dataStartIndex = topicLengthIndex + 2 // Start of the topic-name
            + Int(data[topicLengthIndex] << 8 + data[topicLengthIndex + 1]) // Length of the topic-name

        if (data[0] & 0b0000_0110 != 0) {
            // Packet identifier present because QoS > 0
            dataStartIndex += 2
        }

        if (data.count <= dataStartIndex) {
            DebugService.log("Discarding PUBLISH as message seems to be malformed.")
            DebugService.printBinaryData(data)
            return
        }

        do {
            let topic = try StringEncoder.decodeString(Array(data[topicLengthIndex...]))
            let payload = Array(data[dataStartIndex...])

            if (self.onMessageHandler != nil) {
                self.onMessageHandler!(topic, payload)
            }
        } catch MqttFormatError.invalidStringData {
            DebugService.log("Could not handle message as data is not decodable!")
        } catch {
            DebugService.error(error.localizedDescription)
        }
    }

    private static func convertDataToMessageData(_ data: Data) -> MessageData
    {
        return data.map { (value) -> Int in
            Int(value)
        }
    }
}

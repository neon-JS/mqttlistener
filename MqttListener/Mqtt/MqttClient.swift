import Foundation
import Network

class MqttClient
{
    private let client : Client
    private let clientId : String
    private let userName: String?
    private let password: String?

    private var onMessageHandler: ((String, [Int]) -> Void)?

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

    public func setOnMessageHandler(_ handler: ((String, [Int]) -> Void)?)
    {
        self.onMessageHandler = handler
    }

    private func onData(_ data: Data) -> Void
    {
        do {
            let convertedData = MqttFormatService.dataToIntArray(data)
            let messages = try MqttFormatService.extractMessagesFromData(data: convertedData)

            for message in messages {
                self.onMqttMessage(message)
            }
        } catch {
            DebugService.error("Error while handling incoming data: \(error)")
        }
    }

    private func onMqttMessage(_ message: [Int])
    {
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

    private func handleSubAck(_ data: [Int])
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

        let payloadIndex = Int(5 + data[4])
        if (data[payloadIndex] >= 0b1000_0000) {
            // Payload contains status-code. Every status-code >= 128 indicates an error.
            DebugService.error("Status code indicates an error during SUBACK. Code: \(data[payloadIndex])")
        }
    }

    private func handleConnAck(_ data: [Int])
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

        if (data[2] != 0b0000_0000) {
            DebugService.log("Using resumed session during CONNACK")
        }

        if (data[3] != 0b0000_0000) {
            DebugService.error("Status code indicates an error during CONNACK. Code: \(data[3])")
        }
    }

    private func handlePublish(_ data: [Int])
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

        let topicLength = Int(data[2] << 8 + data[3])
        var dataStart = topicLength + 4

        if (data[0] & 0b0000_0110 != 0) {
            // QoS > 0
            dataStart += 2
        }

        let topic = MqttFormatService.decodeString(Array(data[2..<topicLength + 4]))
        let payload = Array(data[dataStart..<data.count])

        if (self.onMessageHandler != nil) {
            self.onMessageHandler!(topic, payload)
        }
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

        var parts: [[Int]] = [
            try MqttFormatService.encodeString(Mqtt.ProtocolName),
            [
                Mqtt.ProtocolVersion,
                connectFlags,

                0b0000_0000, // Keepalive MSB,
                0b0000_0000, // Keepalive LSB

                0x0000_0000, // Property-length (0 as no properties are set) but necessary for MQTT5
            ],

            try MqttFormatService.encodeString(self.clientId) // Begin of payload
        ]

        if (self.userName != nil) {
            try parts.append(MqttFormatService.encodeString(self.userName!))
        }

        if (self.password != nil) {
            try parts.append(MqttFormatService.encodeString(self.password!))
        }

        try self.client.send(MqttFormatService.convertMessageToData(controlPacketType: Mqtt.ControlPacketTypeConnect, data: parts))
    }

    public func subscribe(topic: String) throws
    {
        if (topic.isEmpty) {
            throw MqttError.emptyTopic
        }

        let parts: [[Int]] = [
            [
                0b0000_0000, // Packet identifier (MSB). We use this to recognize the ACK later. We also choose the identifier ourselves!
                0b0000_1110, // Packet identifier (LSB)

                0b0000_0000, // Properties length. As we dont use them, its 0
            ],
            try MqttFormatService.encodeString(topic),
            [
                0b0000_0110, // Subscription options
            ]
        ]
        try self.client.send(MqttFormatService.convertMessageToData(controlPacketType: Mqtt.ControlPacketTypeSubscribe, data: parts))
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
}

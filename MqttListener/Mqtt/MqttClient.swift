import Foundation
import Network

class MqttClient
{
    private let client : Client
    private let clientId : String
    private let userName: String?
    private let password: String?

    private var onMessage: ((String, [Int]) -> Void)?

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

        self.client.setMessageHandler(handler: self.onMessage(data:))
        self.client.setOnDisconnectHandler(handler: self.onDisconnect(state:error:))
    }

    public func setOnMessage(handler: ((String, [Int]) -> Void)?)
    {
        self.onMessage = handler
    }

    private func onMessage(data: Data) -> Void
    {
        let convertedData = MqttFormatService.dataToIntArray(data: data)
        let controlPacketIdentifier = convertedData[0]

        if (controlPacketIdentifier == Mqtt.ControlPacketTypeConnAck) {
            self.handleConnAck(data: convertedData)
        } else if (controlPacketIdentifier == Mqtt.ControlPacketTypeSubAck) {
            self.handleSubAck(data: convertedData)
        } else if ((controlPacketIdentifier & Mqtt.ControlPacketIdentifierPublish) == Mqtt.ControlPacketIdentifierPublish) {
            self.handlePublish(data: convertedData)
        } else {
            print("DEBUG: Received unspecified message with \(data.count) bytes:")
            for c in data {
                print(c)
            }
        }
    }

    private func handleSubAck(data: [Int])
    {
        print("DEBUG: Got SUBACK")

        /*
            0b1001_0000 // SUBACK
            0bXXXX_XXXX // Remaining length

            0bXXXX_XXXX // Packet identifier from SUBSCRIBE request (MSB)
            0bXXXX_XXXX // Packet identifier from SUBSCRIBE request (LSB)

            0bXXXX_XXXX // Properties length

            0bXXXX_XXXX // Payload
         */

        let payloadIndex = Int(5 + data[4])

        if (data[payloadIndex] >= 0b1000_0000) {
            // Payload contains status-code. Every status-code >= 128 indicates an error.
            print("ERROR: Error code during SUBACK: \(data[payloadIndex])")
        }
    }

    private func handleConnAck(data: [Int])
    {
        print("DEBUG: Got CONNACK")
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

        if (data[2] != 0b0000_0000) {
            print("DEBUG: Using resumed session!")
        } else {
            print("DEBUG: Using clean session!")
        }

        if (data[3] != 0b0000_0000) {
            print("ERROR: Status ERROR! '\(data[3])'")
        }
    }

    private func handlePublish(data: [Int])
    {
        print("DEBUG: Got PUBLISH")
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

        let topicLength = Int(data[2] << 8 + data[3])

        var dataStart = topicLength + 4
        if (data[0] & 0b0000_0110 != 0) {
            // QoS > 0
            dataStart += 2
        }

        let topic = MqttFormatService.decodeString(bytes: Array(data[2..<topicLength + 4]))
        let payload = Array(data[dataStart..<data.count])

        if (self.onMessage != nil) {
            self.onMessage!(topic, payload)
        }
    }

    private func onDisconnect(state: NWConnection.State, error: NWError?) -> Void
    {
     //   print("Disconnected with state '\(state)' and error '\(String(describing: error))'!")
    }

    public func connect()
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
            MqttFormatService.encodeString(value: Mqtt.ProtocolName),
            [
                Mqtt.ProtocolVersion,
                connectFlags,

                0b0000_0000, // Keepalive MSB,
                0b0000_0000, // Keepalive LSB

                0x0000_0000, // Property-length (0 as no properties are set) but necessary for MQTT5
            ],

            MqttFormatService.encodeString(value: self.clientId) // Begin of payload
        ]

        if (self.userName != nil) {
            parts.append(MqttFormatService.encodeString(value: self.userName!))
        }

        if (self.password != nil) {
            parts.append(MqttFormatService.encodeString(value: self.password!))
        }

        try! self.client.send(data: MqttFormatService.convertMessageToData(controlPacketType: Mqtt.ControlPacketTypeConnect, data: parts))
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
            MqttFormatService.encodeString(value: topic),
            [
                0b0000_0110, // Subscription options
            ]
        ]
        try! self.client.send(data: MqttFormatService.convertMessageToData(controlPacketType: Mqtt.ControlPacketTypeSubscribe, data: parts))
    }

    public func disconnect()
    {
        let data = Data([
            UInt8(Mqtt.ControlPacketTypeDisconnect),
            0b0000_0000, // Remaining length

            0b0000_0000, // Reason code -> normal disconnection

            0b0000_0000, // Properties length (empty, therefore 0)
        ])

        try! self.client.send(data: data)
        try! self.client.disconnect()
    }
}

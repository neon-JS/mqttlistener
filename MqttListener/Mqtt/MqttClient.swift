import Foundation
import Network

class MqttClient
{
    private let parserFactory: ParserFactory
    private let messageConverter: MessageConverter

    private let client : Client
    private let clientId : String
    private let userName: String?
    private let password: String?

    private var onMessageHandler: ((String, MessageData) -> Void)?

    public convenience init(
        _ parserFactory: ParserFactory,
        _ messageConverter: MessageConverter,
        _ client: Client,
        clientId: String
    )
    {
        self.init(parserFactory, messageConverter, client, clientId: clientId, userName: nil, password: nil)
    }

    public init(
        _ parserFactory: ParserFactory,
        _ messageConverter: MessageConverter,
        _ client: Client,
        clientId: String,
        userName: String?,
        password: String?
    )
    {
        self.parserFactory = parserFactory
        self.messageConverter = messageConverter
        self.client = client

        self.clientId = clientId
        self.userName = userName
        self.password = password

        self.client.setOnDataHandler(self.onData)
    }

    public func setOnMessageHandler(_ handler: ((String, MessageData) -> Void)?)
    {
        self.onMessageHandler = handler
    }

    public func connect() throws
    {
        let stringEncoder = self.parserFactory.getStringEncoder()

        // Build connect flags
        var connectFlags = Mqtt.ConnectFlagCleanStart // Starting with a clean session. As this is just a plain listener, we won't use a will!

        if (self.userName != nil) {
            connectFlags |= Mqtt.ConnectFlagUseUserName
        }

        if (self.password != nil) {
            connectFlags |= Mqtt.ConnectFlagUsePassword
        }

        var parts: [MessageData] = [
            try stringEncoder.encode(Mqtt.ProtocolName),
            [
                Mqtt.ProtocolVersion,
                connectFlags,

                0b0000_0000, // Keepalive MSB,
                0b0000_0000, // Keepalive LSB

                0x0000_0000, // Property-length (0 as no properties are set) but necessary for MQTT5
            ],

            try stringEncoder.encode(self.clientId) // Begin of payload
        ]

        if (self.userName != nil) {
            try parts.append(stringEncoder.encode(self.userName!))
        }

        if (self.password != nil) {
            try parts.append(stringEncoder.encode(self.password!))
        }

        try self.client.send(self.messageConverter.convertToData(controlPacketType: Mqtt.ControlPacketTypeConnect, messageParts: parts))
    }

    public func subscribe(topic: String) throws
    {
        if (topic.isEmpty) {
            throw MqttFormatError.emptyTopic
        }

        let subscriptionOptions = Mqtt.SubscribeOptionFlagQoS2 | Mqtt.SubscribeOptionNoLocale | Mqtt.SubscribeOptionRetainedMessageOnlyOnNewSubscription

        let parts: [MessageData] = [
            [
                0b0000_0000, // Packet identifier (MSB). We use this to recognize the ACK later. We also choose the identifier ourselves!
                0b0000_1110, // Packet identifier (LSB)

                0b0000_0000, // Properties length. As we dont use them, its 0
            ],
            try self.parserFactory.getStringEncoder().encode(topic),
            [
                subscriptionOptions,
            ]
        ]
        try self.client.send(self.messageConverter.convertToData(controlPacketType: Mqtt.ControlPacketTypeSubscribe, messageParts: parts))
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
            let messages = try self.messageConverter.extractMessages(data)
            for message in messages {
                try self.onMqttMessage(message)
            }
        } catch {
            DebugService.error("Error while handling incoming data: \(error)")
        }
    }

    private func onMqttMessage(_ message: MessageData) throws
    {
        if (message.count == 0) {
            DebugService.log("Discarding empty message!")
            return
        }

        let controlPacketIdentifier = message[0]

        if (controlPacketIdentifier == Mqtt.ControlPacketTypeConnAck) {
            try self.handleConnAck(message)
        } else if (controlPacketIdentifier == Mqtt.ControlPacketTypeSubAck) {
            try self.handleSubAck(message)
        } else if ((controlPacketIdentifier & Mqtt.ControlPacketIdentifierPublish) == Mqtt.ControlPacketIdentifierPublish) {
            try self.handlePublish(message)
        } else {
            DebugService.log("Received unspecified message with \(message.count) bytes:")
            DebugService.printBinaryData(message)
        }
    }

    private func handleSubAck(_ data: MessageData) throws
    {
        DebugService.log("Got SUBACK")

        let message = try self.parserFactory.getSubackParser().parse(message: data)

        if (message.payload == nil || message.payload!.count == 0) {
            DebugService.log("Discarding SUBACK as message seems to be malformed.")
            DebugService.printBinaryData(data)
            return
        }

        if (message.payload![0] >= 0b1000_0000) {
            // Payload contains status-code. Every status-code >= 128 indicates an error.
            DebugService.error("Status code indicates an error during SUBACK. Code: \(message.payload![0])")
        }
    }

    private func handleConnAck(_ data: MessageData) throws
    {
        DebugService.log("Got CONNACK")

        let message = try self.parserFactory.getConnackParser().parse(message: data)

        if (message.reasonCode != Mqtt.ConnackReasonCodeSuccess) {
            DebugService.error("Status code indicates an error during CONNACK. Code: \(String(describing: message.reasonCode))")
            return
        }

        if (message.connackFlags == Mqtt.ConnackFlagSessionPresent) {
            DebugService.log("Using present session during CONNACK")
        }
    }

    private func handlePublish(_ data: MessageData) throws
    {
        DebugService.log("Got PUBLISH")

        let message = try self.parserFactory.getPublishParser().parse(message: data)
        if (self.onMessageHandler != nil) {
            self.onMessageHandler!(message.topicName!, message.payload!)
        }
    }
}

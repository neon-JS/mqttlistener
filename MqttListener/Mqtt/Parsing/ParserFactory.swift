import Foundation

class ParserFactory
{
    public static var instance = ParserFactory()

    private var publishParser: PublishParser?
    private var connackParser: ConnackParser?
    private var subackParser: SubackParser?

    private var fixedHeaderParser: FixedHeaderParser?
    private var remainingLengthParser: RemainingLengthParser?
    private var topicNameParser: TopicNameParser?
    private var packetIdentifierParser: PacketIdentifierParser?
    private var propertiesParser: PropertiesParser?
    private var payloadParser: PayloadParser?
    private var reasonCodeParser: ReasonCodeParser?
    private var byteValueParser: ByteValueParser?

    private var stringEncoder: StringEncoder?
    private var integerEncoder: IntegerEncoder?

    private init()
    {
        self.fixedHeaderParser = nil
        self.remainingLengthParser = nil
        self.topicNameParser = nil
        self.packetIdentifierParser = nil
        self.propertiesParser = nil
        self.payloadParser = nil
        self.reasonCodeParser = nil

        self.stringEncoder = nil
        self.integerEncoder = nil
    }

    public func getPublishParser() -> PublishParser
    {
        self.publishParser = self.publishParser ?? PublishParser(
            self.getFixedHeaderParser(),
            self.getRemainingLengthParser(),
            self.getTopicNameParser(),
            self.getPacketIdentifierParser(),
            self.getPropertiesParser(),
            self.getPayloadParser()
        )
        return self.publishParser!
    }

    public func getConnackParser() -> ConnackParser
    {
        self.connackParser = self.connackParser ?? ConnackParser(
            self.getFixedHeaderParser(),
            self.getRemainingLengthParser(),
            self.getByteValueParser(),
            self.getReasonCodeParser(),
            self.getPropertiesParser()
        )
        return self.connackParser!
    }

    public func getSubackParser() -> SubackParser
    {
        self.subackParser = self.subackParser ?? SubackParser(
            self.getFixedHeaderParser(),
            self.getRemainingLengthParser(),
            self.getPacketIdentifierParser(),
            self.getPropertiesParser(),
            self.getPayloadParser()
        )
        return self.subackParser!
    }

    private func getFixedHeaderParser() -> FixedHeaderParser
    {
        self.fixedHeaderParser = self.fixedHeaderParser ?? FixedHeaderParser()
        return self.fixedHeaderParser!
    }

    private func getRemainingLengthParser() -> RemainingLengthParser
    {
        self.remainingLengthParser = self.remainingLengthParser ?? RemainingLengthParser(self.getIntegerEncoder())
        return self.remainingLengthParser!
    }

    private func getTopicNameParser() -> TopicNameParser
    {
        self.topicNameParser = self.topicNameParser ?? TopicNameParser(self.getStringEncoder())
        return self.topicNameParser!
    }

    private func getPacketIdentifierParser() -> PacketIdentifierParser
    {
        self.packetIdentifierParser = self.packetIdentifierParser ?? PacketIdentifierParser()
        return self.packetIdentifierParser!
    }

    private func getPropertiesParser() -> PropertiesParser
    {
        self.propertiesParser = self.propertiesParser ?? PropertiesParser(self.getIntegerEncoder())
        return self.propertiesParser!
    }

    private func getPayloadParser() -> PayloadParser
    {
        self.payloadParser = self.payloadParser ?? PayloadParser()
        return self.payloadParser!
    }

    private func getReasonCodeParser() -> ReasonCodeParser
    {
        self.reasonCodeParser = self.reasonCodeParser ?? ReasonCodeParser()
        return self.reasonCodeParser!
    }

    private func getByteValueParser() -> ByteValueParser
    {
        self.byteValueParser = self.byteValueParser ?? ByteValueParser()
        return self.byteValueParser!
    }

    public func getStringEncoder() -> StringEncoder
    {
        self.stringEncoder = self.stringEncoder ?? StringEncoder()
        return self.stringEncoder!
    }

    public func getIntegerEncoder() -> IntegerEncoder
    {
        self.integerEncoder = self.integerEncoder ?? IntegerEncoder()
        return self.integerEncoder!
    }
}

// see https://forums.swift.org/t/socket-api/19971/10

import Foundation
import Network

class NetworkClient : Client
{
    private var connection: NWConnection
    private var onDisconnectHandler: ((NWConnection.State, NWError?) -> Void)?
    private var onDataHandler: ((Data) -> Void)?

    init(host: NWEndpoint.Host, port: NWEndpoint.Port)
    {
        self.connection = NWConnection(host: host, port: port, using: NWParameters.tcp)
        self.connection.stateUpdateHandler = self.handleStateChange
        self.handleIncoming()
    }

    public func connect() throws
    {
        if self.connection.state != NWConnection.State.setup {
            throw NetworkClientError.invalidState(
                state: self.connection.state,
                expected: NWConnection.State.setup
            )
        }

        self.connection.start(queue: DispatchQueue.main)
    }

    public func disconnect() throws
    {
        self.terminate(error: nil)
    }

    public func send(_ data: Data) throws
    {
        self.connection.send(
            content: data,
            completion: .contentProcessed( { error in
            if let error = error {
                self.terminate(error: error)
                return
            }
        }))
    }

    public func setOnDataHandler(_ handler: ((Data) -> Void)?)
    {
        self.onDataHandler = handler
    }

    public func setOnDisconnectHandler(_ handler: ((NWConnection.State, NWError?) -> Void)?)
    {
        self.onDisconnectHandler = handler
    }

    private func handleStateChange(_ state: NWConnection.State)
    {
        switch state {
        case .waiting(let error):
            self.terminate(error: error)
            break
        case .failed(let error):
            self.terminate(error: error)
         default:
            break
        }
    }

    private func handleIncoming()
    {
        if (self.connection.state == NWConnection.State.cancelled) {
            return
        }

        self.connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: 65535,
            completion: { (data: Data?, context: NWConnection.ContentContext?, isComplete: Bool, error: NWError?) in

                defer {
                    if error == nil, !isComplete {
                        self.handleIncoming()
                    }
                }

                if let error = error {
                    self.terminate(error: error)
                    return
                }

                if let data = data, !data.isEmpty, self.onDataHandler != nil {
                    self.onDataHandler!(data)
                    return
                }

                if isComplete {
                    self.terminate()
                }
        })
    }

    private func terminate(error: NWError? = nil)
    {
        let disconnectionState = self.connection.state

        if (disconnectionState != NWConnection.State.cancelled) {
            self.connection.stateUpdateHandler = nil
            self.connection.cancel()
        }

        if self.onDisconnectHandler != nil {
            self.onDisconnectHandler!(disconnectionState, error)
        }

        if error != nil && disconnectionState != NWConnection.State.cancelled {
            DebugService.error("Connection terminated with error: '\(error!)'")
        }
    }
}

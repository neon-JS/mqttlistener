import Foundation
import Network;

enum NetworkClientError : Error {
    case invalidState(state: NWConnection.State, expected: NWConnection.State)
}

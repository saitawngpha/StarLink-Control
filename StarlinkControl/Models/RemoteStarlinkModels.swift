import Foundation

struct RemoteStarlinkProfile: Equatable {
    var accountName: String
    var email: String
    var accountID: String
    var serviceLine: String
    var planName: String
    var dishID: String
    var routerID: String
    var latitude: Double
    var longitude: Double
    var address: String
}

struct StarlinkAccountResponse: Decodable {
    var email: String?
    var name: String?
    var givenName: String?
    var familyName: String?
    var accountId: String?
}

struct StarlinkServiceLinesResponse: Decodable {
    var content: Content?

    struct Content: Decodable {
        var results: [ServiceLine]?
    }

    struct ServiceLine: Decodable {
        var serviceLineNumber: String?
        var nickname: String?
        var displayName: String?
        var serviceAddress: ServiceAddress?
        var userTerminals: [UserTerminal]?
        var subscription: Subscription?
    }

    struct ServiceAddress: Decodable {
        var formattedAddress: String?
    }

    struct Subscription: Decodable {
        var productDescription: String?
    }

    struct UserTerminal: Decodable {
        var userTerminalId: String?
        var serialNumber: String?
        var dishSerialNumber: String?
        var latitude: Double?
        var longitude: Double?
        var nickname: String?
        var routers: [Router]?
    }

    struct Router: Decodable {
        var routerId: String?
        var nickname: String?
        var isBypassed: Bool?
    }
}

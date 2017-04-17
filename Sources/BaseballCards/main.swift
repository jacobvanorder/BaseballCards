import Kitura
import SwiftyJSON
import Foundation
import CouchDB //1

//MARK: Database
let connectionProperties = ConnectionProperties(host: "127.0.0.1",
                                                port: 5984,
                                                secured: false) //2
let client = CouchDBClient(connectionProperties: connectionProperties) //3
let database = client.database("baseball_cards")

let router = Router()

var cards = [BaseballCard]()

router.get("/") {
    (request: RouterRequest,
    response: RouterResponse,
    next: @escaping () -> Void) in
    
    response.send("Hello, World!")
    next()
}

//MARK: PUT
router.put("api/v2/card", middleware: BodyParser())
router.put("api/v2/card") {
    (request, response, next) in
    
    guard
        let contentType = request.headers["Content-Type"],
        contentType == "application/json",
        let body = request.body else {
            _ = response.send(status: .badRequest)
            next()
            return
    }
    
    guard
        case var .json(cardJson) = body else {
            _ = response.send(status: .unsupportedMediaType)
            next()
            return
    }
    
    cardJson["type"].stringValue = "BaseballCard" //1
    
    database.create(cardJson, callback: { //2
        (optionalID: String?,
        optionalRevision: String?,
        optionalDocument: JSON?,
        optionalError: Error?) in
        
        guard
            let id = optionalID,
            let revision = optionalRevision,
            let document = optionalDocument else {
                _ = response.send(status: .internalServerError) //3
                next()
                return
        }
        
        
        _ = response.send(id) //4
        next()
    })
}

//MARK: GET
router.get("api/v1/card/:id") {
    (request, response, next) in
    
    guard
        let id = request.parameters["id"] else {
            _ = response.send(status: .badRequest)
            next()
            return
    }
    
    if
        let card = cards.filter({$0.id == id}).first {
        response.send(json: JSON(card.dictionaryRepresentation))
        next()
    }
    else {
        _ = response.send(status: .notFound)
        next()
    }
}

//MARK: POST
router.post("api/v1/card/:id", middleware: BodyParser())
router.post("api/v1/card/:id") {
    (request, response, next) in
    
    guard
        let contentType = request.headers["Content-Type"],
        contentType == "application/json",
        let body = request.body,
        let id = request.parameters["id"] else {
            _ = response.send(status: .badRequest)
            next()
            return
    }
    
    guard
        case let .json(cardJson) = body else {
            _ = response.send(status: .unsupportedMediaType)
            next()
            return
    }
    
    guard
        let oldCardIndex = cards.index(where: {$0.id == id}) else {
            _ = response.send(status: .notFound)
            next()
            return
    }
    
    let newCard = BaseballCard(playerName: cardJson["playerName"].stringValue,
                               teamNames: cardJson["teamNames"].arrayValue.map({$0.stringValue}),
                               year: cardJson["year"].intValue,
                               cardNumber: cardJson["cardNumber"].stringValue,
                               cardCompanyName: cardJson["cardCompanyName"].stringValue,
                               id: id)
    
    cards[oldCardIndex] = newCard
    _ = response.send(status: .OK)
    next()
}

//MARK: DELETE
router.delete("api/v1/card/:id") {
    (request, response, next) in
    
    guard
        let id = request.parameters["id"] else {
            _ = response.send(status: .badRequest)
            next()
            return
    }
    
    guard
        let oldCardIndex = cards.index(where: {$0.id == id}) else {
            _ = response.send(status: .notFound)
            next()
            return
    }
    
    cards.remove(at: oldCardIndex)
    _ = response.send(status: .OK)
    next()
}

Kitura.addHTTPServer(onPort: 8090, with: router)
Kitura.run()

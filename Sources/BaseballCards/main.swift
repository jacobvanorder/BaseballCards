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
router.get("api/v2/card/:id") {
    (request, response, next) in

    guard
        let id = request.parameters["id"] else {
            _ = response.send(status: .badRequest)
            next()
            return
    }

    database.retrieve(id, callback: { //1
        (optionalJsonDocument: JSON?, optionalError: Error?) in

        if
            let jsonDocument = optionalJsonDocument,
            jsonDocument["error"].string == .none { //2
            let cardJson = BaseballCard.json(from: jsonDocument, with: id) //3
            _ = response.send(json: cardJson)
        }
        else {
            _ = response.send(status: .notFound) //4
            next()
        }
    })
}

//MARK: POST
router.post("api/v2/card/:id", middleware: BodyParser())
router.post("api/v2/card/:id") {
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
        case var .json(cardJson) = body else {
            _ = response.send(status: .unsupportedMediaType)
            next()
            return
    }
    
    database.retrieve(id, //1
        callback: {
            (optionalJSONDocument, optionalError) in
            
            guard
                let jsonDocument = optionalJSONDocument,
                let revision = jsonDocument["_rev"].string else { //2
                    _ = response.send(status: .notFound)
                    next()
                    return
            }
            
            cardJson["type"].stringValue = "BaseballCard" //3
            
            database.update(id, //4
                rev: revision,
                document: cardJson,
                callback: {
                    (optionalUpdatedRevision, optionalUpdatedJSONDocument, optionalError) in
                    
                    guard
                        let updatedRevision = optionalUpdatedRevision,
                        let updatedDocument = optionalUpdatedJSONDocument,
                        revision != updatedRevision else { //5
                            _ = response.send(status: .internalServerError) //6
                            next()
                            return
                    }
                    
                    _ = response.send(status: .OK) //7
                    next()
            })
    })
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

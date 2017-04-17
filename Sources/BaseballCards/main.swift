import Kitura
import SwiftyJSON
import Foundation
import CouchDB

//MARK: Database
let connectionProperties = ConnectionProperties(host: "127.0.0.1",
                                                port: 5984,
                                                secured: false)
let client = CouchDBClient(connectionProperties: connectionProperties)
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
    
    cardJson["type"].stringValue = "BaseballCard"
    
    database.create(cardJson, callback: {
        (optionalID: String?,
        optionalRevision: String?,
        optionalDocument: JSON?,
        optionalError: Error?) in
        
        guard
            let id = optionalID,
            let revision = optionalRevision,
            let document = optionalDocument else {
                _ = response.send(status: .internalServerError)
                next()
                return
        }
        
        
        _ = response.send(id)
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
    
    database.retrieve(id, callback: {
        (optionalJsonDocument: JSON?, optionalError: Error?) in
        
        if
            let jsonDocument = optionalJsonDocument,
            jsonDocument["error"].string == .none { 
            let cardJson = BaseballCard.json(from: jsonDocument, with: id) 
            _ = response.send(json: cardJson)
        }
        else {
            _ = response.send(status: .notFound)
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
    
    database.retrieve(id,
                      callback: {
                        (optionalJSONDocument, optionalError) in
                        
                        guard
                            let jsonDocument = optionalJSONDocument,
                            let revision = jsonDocument["_rev"].string else {
                                _ = response.send(status: .notFound)
                                next()
                                return
                        }
                        
                        cardJson["type"].stringValue = "BaseballCard"
                        
                        database.update(id,
                                        rev: revision,
                                        document: cardJson,
                                        callback: {
                                            (optionalUpdatedRevision, optionalUpdatedJSONDocument, optionalError) in
                                            
                                            guard
                                                let updatedRevision = optionalUpdatedRevision,
                                                let updatedDocument = optionalUpdatedJSONDocument,
                                                revision != updatedRevision else {
                                                    _ = response.send(status: .internalServerError)
                                                    next()
                                                    return
                                            }
                                            
                                            _ = response.send(status: .OK)
                                            next()
                        })
    })
}

//MARK: DELETE

router.delete("api/v2/card/:id") {
    (request, response, next) in
    
    guard
        let id = request.parameters["id"] else {
            _ = response.send(status: .badRequest)
            next()
            return
    }
    
    database.retrieve(id,
                      callback: {
                        (optionalJSONDocument, optionalError) in
                        
                        guard
                            let jsonDocument = optionalJSONDocument,
                            let revision = jsonDocument["_rev"].string else {
                                _ = response.send(status: .notFound)
                                next()
                                return
                        }
                        
                        database.delete(id,
                                        rev: revision, callback: {
                                            (optionalError: NSError?) in
                                            
                                            if let error = optionalError {
                                                _ = response.send(status: .internalServerError)
                                                next()
                                                return
                                            }
                                            else {
                                                _ = response.send(status: .OK)
                                                next()
                                                return
                                            }
                        })
    })
}

//MARK: Images
//MARK: PUT
router.put("/api/v1/card_image/:id", middleware: BodyParser()) //1
router.put("/api/v1/card_image/:id") {
    (request, response, next) in
    
    guard
        let id = request.parameters["id"],
        let content = request.headers["Content-Type"],
        content == "image/jpeg",
        let body = request.body,
        case let .raw(imageData) = body else { //2
            _ = response.send(status: .badRequest)
            next()
            return
    }
    
    database.retrieve(id, callback: { //3
        (optionalJSONDocument, optionalError) in
        
        guard
            let jsonDocument = optionalJSONDocument,
            let revision = jsonDocument["_rev"].string else {
                _ = response.send(status: .notFound)
                next()
                return
        }
        
        database.createAttachment(id, //4
            docRevison: revision,
            attachmentName: "image" + id,
            attachmentData: imageData,
            contentType: content,
            callback: {
                (optionalNewRevision, optionalDocument, optionalError) in
                
                defer { next() }
                
                if
                    let _ = optionalNewRevision,
                    let _ = optionalDocument {
                    _ = response.send(status: .OK) //5
                }
                else {
                    _ = response.send(status: .notModified)
                }
        })
    })
    
}

//MARK: GET
router.get("/api/v1/card_image/:id") {
    (request, response, next) in
    
    guard
        let id = request.parameters["id"],
        let accept = request.headers["Accept"],
        accept == "image/jpeg" else { //1
            _ = response.send(status: .badRequest)
            next()
            return
    }
    
    database.retrieveAttachment(id, //2
                                attachmentName: "image" + id,
                                callback: {
                                    (optionalData, optionalError, optionalImageType) in
                                    
                                    defer { next() }
                                    
                                    if let error = optionalError { //3
                                        _ = response.send(status: .notFound)
                                    }
                                    else if let data = optionalData {
                                        response.send(data: data) //4
                                    }
    })
}

Kitura.addHTTPServer(onPort: 8090, with: router)
Kitura.run()

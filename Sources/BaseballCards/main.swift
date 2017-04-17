import Kitura
import SwiftyJSON
import Foundation
import CouchDB

import Kitura_CredentialsTwitter //1
import Credentials
import KituraSession

//MARK: Database
let connectionProperties = ConnectionProperties(host: "127.0.0.1",
                                                port: 5984,
                                                secured: false)
let client = CouchDBClient(connectionProperties: connectionProperties)
let database = client.database("baseball_cards")

let router = Router()

let session = Session(secret: "I thought I told you to trim those sideburns!") //2
router.all(middleware: session)

let twitter = CredentialsTwitterVerify(consumerKey: consumerKey,
                                       consumerSecret: consumerSecret) //3
let credentials = Credentials() //4
credentials.register(plugin: twitter) //5

//For talk purposes only
let twitterWebAuth = CredentialsTwitter(consumerKey: consumerKey,
                                        consumerSecret: consumerSecret)
credentials.register(plugin: twitterWebAuth)
credentials.options["failureRedirect"] = "/login/twitter/token"

router.get("/login/twitter/token",
           handler: credentials.authenticate(credentialsType: twitterWebAuth.name))

router.get("/login/twitter/token/callback",
           handler: credentials.authenticate(credentialsType: twitterWebAuth.name))

/// This is just here for me to authenticate and quickly get token and token secrets during the talk. IRL, your client
/// wouldn't do this.
router.get("/faux_login", middleware: credentials)
router.get("/faux_login") {
    (request, response, next) in
    response.send("\(twitterWebAuth.oAuthToken), \(twitterWebAuth.oAuthTokenSecret)")
    next()
}

router.get("/") {
    (request: RouterRequest,
    response: RouterResponse,
    next: @escaping () -> Void) in
    
    response.send("Hello, World!")
    next()
}

//MARK: PUT
router.put("api/v3/card", middleware: [BodyParser(), credentials]) //1
router.put("api/v3/card") {
    (request, response, next) in
    
    guard
        let contentType = request.headers["Content-Type"],
        contentType == "application/json",
        let body = request.body,
        let user = request.userProfile else { //1
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
    cardJson["userID"].stringValue = user.id //2
    
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
router.get("api/v3/card/:id", middleware: credentials) //1
router.get("api/v3/card/:id") {
    (request, response, next) in
    
    guard
        let id = request.parameters["id"],
        let user = request.userProfile else { //2
            _ = response.send(status: .badRequest)
            next()
            return
    }
    
    database.retrieve(id, callback: {
        (optionalJsonDocument: JSON?, optionalError: Error?) in
        
        if
            let jsonDocument = optionalJsonDocument,
            jsonDocument["error"].string == .none {
            if jsonDocument["userID"].stringValue == user.id { //3
                let cardJson = BaseballCard.json(from: jsonDocument, with: id)
                _ = response.send(json: cardJson)
                next()
            }
            else {
                _ = response.send(status: .unauthorized) //4
                next()
            }
        }
        else {
            _ = response.send(status: .notFound)
            next()
        }
    })
}

//MARK: POST
router.post("api/v3/card/:id", middleware: [BodyParser(), credentials]) //1
router.post("api/v3/card/:id") {
    (request, response, next) in
    
    guard
        let contentType = request.headers["Content-Type"],
        contentType == "application/json",
        let body = request.body,
        let id = request.parameters["id"],
        let user = request.userProfile else { //2
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
                        
                        if jsonDocument["userID"].stringValue != user.id { //3
                            _ = response.send(status: .unauthorized) //4
                            next()
                            return
                        }
                        
                        cardJson["type"].stringValue = "BaseballCard"
                        cardJson["userID"].stringValue = user.id //5
                        
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
router.put("/api/v1/card_image/:id", middleware: BodyParser()) 
router.put("/api/v1/card_image/:id") {
    (request, response, next) in
    
    guard
        let id = request.parameters["id"],
        let content = request.headers["Content-Type"],
        content == "image/jpeg",
        let body = request.body,
        case let .raw(imageData) = body else { 
            _ = response.send(status: .badRequest)
            next()
            return
    }
    
    database.retrieve(id, callback: { 
        (optionalJSONDocument, optionalError) in
        
        guard
            let jsonDocument = optionalJSONDocument,
            let revision = jsonDocument["_rev"].string else {
                _ = response.send(status: .notFound)
                next()
                return
        }
        
        database.createAttachment(id, 
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
                    _ = response.send(status: .OK) 
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
        accept == "image/jpeg" else { 
            _ = response.send(status: .badRequest)
            next()
            return
    }
    
    database.retrieveAttachment(id, 
                                attachmentName: "image" + id,
                                callback: {
                                    (optionalData, optionalError, optionalImageType) in
                                    
                                    defer { next() }
                                    
                                    if let error = optionalError { 
                                        _ = response.send(status: .notFound)
                                    }
                                    else if let data = optionalData {
                                        response.send(data: data) 
                                    }
    })
}

Kitura.addHTTPServer(onPort: 8090, with: router)
Kitura.run()

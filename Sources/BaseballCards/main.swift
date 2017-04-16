import Kitura
import SwiftyJSON //1
import Foundation

let router = Router()

var cards = [BaseballCard]() //2

router.get("/") {
    (request: RouterRequest,
    response: RouterResponse,
    next: @escaping () -> Void) in

    response.send("Hello, World!")
    next()
}

//MARK: PUT
router.put("api/v1/card", middleware: BodyParser()) //3
router.put("api/v1/card") { //4
    (request, response, next) in

    guard
        let contentType = request.headers["Content-Type"], //5
        contentType == "application/json",
        let body = request.body else {
            _ = response.send(status: .badRequest)
            next()
            return
    }

    guard
        case let .json(cardJson) = body else { //6
            _ = response.send(status: .unsupportedMediaType)
            next()
            return
    }

    let card = BaseballCard(playerName: cardJson["playerName"].stringValue,
                            teamNames: cardJson["teamNames"].arrayValue.map({$0.stringValue}),
                            year: cardJson["year"].intValue,
                            cardNumber: cardJson["cardNumber"].stringValue,
                            cardCompanyName: cardJson["cardCompanyName"].stringValue,
                            id: UUID().uuidString) //7

    cards.append(card) //8

    _ = response.send(card.id) //9
    next()
}

//MARK: GET
router.get("api/v1/card/:id") { //1
    (request, response, next) in

    guard
        let id = request.parameters["id"] else { //2
            _ = response.send(status: .badRequest)
            next()
            return
    }

    if
        let card = cards.filter({$0.id == id}).first { //3
        response.send(json: JSON(card.dictionaryRepresentation)) //4
        next()
    }
    else {
        _ = response.send(status: .notFound) //5
        next()
    }
}

//MARK: POST
router.post("api/v1/card/:id", middleware: BodyParser()) //1
router.post("api/v1/card/:id") { //2
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
        case let .json(cardJson) = body else { //4
            _ = response.send(status: .unsupportedMediaType)
            next()
            return
    }

    guard
        let oldCardIndex = cards.index(where: {$0.id == id}) else { //5
            _ = response.send(status: .notFound) //6
            next()
            return
    }

    let newCard = BaseballCard(playerName: cardJson["playerName"].stringValue,
                               teamNames: cardJson["teamNames"].arrayValue.map({$0.stringValue}),
                               year: cardJson["year"].intValue,
                               cardNumber: cardJson["cardNumber"].stringValue,
                               cardCompanyName: cardJson["cardCompanyName"].stringValue,
                               id: id) //7

    cards[oldCardIndex] = newCard //8
    _ = response.send(status: .OK)
    next()
}

//MARK: DELETE
router.delete("api/v1/card/:id") { //1
    (request, response, next) in

    guard
        let id = request.parameters["id"] else { //2
            _ = response.send(status: .badRequest)
            next()
            return
    }

    guard
        let oldCardIndex = cards.index(where: {$0.id == id}) else { //3
            _ = response.send(status: .notFound) //4
            next()
            return
    }

    cards.remove(at: oldCardIndex) //5
    _ = response.send(status: .OK)
    next()
}

Kitura.addHTTPServer(onPort: 8090, with: router)
Kitura.run()

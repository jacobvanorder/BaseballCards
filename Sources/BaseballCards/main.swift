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

Kitura.addHTTPServer(onPort: 8090, with: router)
Kitura.run()

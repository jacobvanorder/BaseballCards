//
//  BaseballCard.swift
//  BaseballCards
//
//  Created by Jacob Van Order on 3/13/17.
//
//

import Foundation
import SwiftyJSON

struct BaseballCard {
    let playerName: String
    let teamNames: [String]
    let year: Int
    let cardNumber: String
    let cardCompanyName: String
    let id: String
//    let userID: String //Authentication
    
    //Convenience method that will return a dictionary with the keys and values of the BaseballCard's properties.
    var dictionaryRepresentation: [String: Any] {
        return ["playerName": self.playerName,
                "teamNames": self.teamNames,
                "year": self.year,
                "cardNumber": self.cardNumber,
                "cardCompanyName": self.cardCompanyName,
                "id": self.id,
                /*"userID": self.userID,*/]
    }
    
    //Convenience method that will return a SwiftyJSON object of the BaseballCard.
    static func json(from couchDocument: JSON, with id: String, from userID: String? = .none) -> JSON {
        return JSON(BaseballCard.dictionary(from: couchDocument, with: id, from: userID))
    }
    
    //Convenience method that will return a dictionary with the keys and values of the BaseballCard's properties.
    static func dictionary(from couchDocument: JSON, with id: String, from userID: String? = .none) -> [String: Any] {
        var dictionary = [String: Any]()
        dictionary["id"] = id
        /*dictionary["userID"] = userID ?? couchDocument["userID"].string ?? ""*/
        dictionary["playerName"] = couchDocument["playerName"].string
        dictionary["teamNames"] = couchDocument["teamNames"].array?.flatMap({$0.string})
        dictionary["year"] = couchDocument["year"].int
        dictionary["cardNumber"] = couchDocument["cardNumber"].string
        dictionary["cardCompanyName"] = couchDocument["cardCompanyName"].string
        
        return dictionary
    }
}

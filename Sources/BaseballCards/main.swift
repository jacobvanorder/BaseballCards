import Kitura //1

let router = Router() //2

router.get("/") { //3
    (request: RouterRequest,
    response: RouterResponse,
    next: @escaping () -> Void) in //4
    
    response.send("Hello, World!") //5
    next() //6
}

Kitura.addHTTPServer(onPort: 8090, with: router)
Kitura.run() //7

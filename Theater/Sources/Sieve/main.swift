import Theater
import Foundation

class Start: Actor.Message {}
class Number: Actor.Message {
    var n: Int
    
    init(n: Int, sender: ActorRef!) {
        self.n = n
        super.init(sender: sender)
    }
}

// Global timer
var startTime: Double = 0.0
var endTime: Double = 0.0

class Filter: Actor {
    let myPrime: Int
    let client: ActorRef
    var next: ActorRef?
    
    required init(context: ActorCell, prime: Int, client: ActorRef) {
        self.myPrime = prime
        self.client = client
        super.init(context: context)
    }
    
    override func preStart() {
        client ! Number(n: myPrime, sender: this)
    }
    
    override func receive(_ msg: Actor.Message) throws {
        switch msg {
        case let num as Number:
            if num.n % myPrime != 0 {
                if let nextFilter = next {
                    nextFilter ! msg
                } else {
                    next = context.actorOf { context in
                        Filter(context: context, prime: num.n, client: self.client)
                    }
                }
            } else {
                
            }
        default:
            print("Filter actor got unexpected message: \(msg)")
        }
    }
}

class Root: Actor {
    let max: Int
    var first: ActorRef!
    
    required init(context: ActorCell, max: Int) {
        self.max = max
        super.init(context: context)
    }
    
    override func preStart() {
        first = context.actorOf(name: "first") { context in
            Filter(context: context, prime: 2, client: self.this)
        }
    }
    
    override func childTerminated(_ child: ActorRef) {
        print("all done")
        endTime = Date().timeIntervalSince1970
        print("Stop: \(Date())")
        print("Duration: \(endTime - startTime)")
        exit(0)
    }
    
    override func postStop() {
        print("all done")
        endTime = Date().timeIntervalSince1970
        print("Stop: \(Date())")
        print("Duration: \(endTime - startTime)")
//        this ! PoisonPill(sender: this)
        exit(0)
    }
    
    override func receive(_ msg: Actor.Message) throws {
        switch msg {
        case is Start:
            startTime = Date().timeIntervalSince1970
            print("Start: \(Date())")
            for i in 3..<max {
                first ! Number(n: i, sender: this)
            }
            first ! PoisonPill(sender: this)
        case let num as Number: //break
            print(num.n)
        default:
            print("Root actor got unexpected message: \(msg)")
        }
    }
}

var max = 1000
if CommandLine.arguments.count == 2, let arg = Int(CommandLine.arguments[1]) {
    max = arg
}

print("Max is \(max)")
let system = ActorSystem(name: "Sieve")
let root = system.actorOf(name: "root") { context in
    Root(context: context, max: max)
}
root ! Start(sender: nil)

sleep(300)

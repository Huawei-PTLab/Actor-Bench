import Sam
import Foundation

enum SieveMessage: Message {
    case start
    case number(Int)
}

// Global timer
var startTime: Double = 0.0
var endTime: Double = 0.0

struct Filter: Actor {
    unowned let actorContext: KnownActorCell<Filter>
    var context: ActorCell {
        get { return actorContext }
    }
    
    typealias ActorMessage = SieveMessage
    
    let myPrime: Int
    let client: KnownActorRef<Root>
    var next: KnownActorRef<Filter>?
    
    init(context: KnownActorCell<Filter>, prime: Int, client: KnownActorRef<Root>) {
        self.actorContext = context
        self.myPrime = prime
        self.client = client
    }
    
    func preStart() {
        client ! .number(myPrime)
    }
    
    mutating func receive(_ msg: SieveMessage) {
        switch msg {
        case .number(let n):
            if n % myPrime != 0 {
                if let nextFilter = next {
                    nextFilter ! msg
                } else {
                    unowned let client = self.client
                    next = context.actorOf { context in
                        Filter(context: context, prime: n, client: client)
                    }
                }
            } else {
                
            }
        default:
            print("Filter actor got unexpected message: \(msg)")
        }
    }
    
    public func supervisorStrategy(error: Error) { }
    public func willStop() { }
    public func postStop() { }
    public func childTerminated(_ child: ActorRef) { }
}

struct Root: Actor {
    unowned let actorContext: KnownActorCell<Root>
    var context: ActorCell {
        get { return actorContext }
    }
    
    typealias ActorMessage = SieveMessage
    
    let max: Int
    var first: KnownActorRef<Filter>!
    
    init(context: KnownActorCell<Root>, max: Int) {
        self.actorContext = context
        self.max = max
    }
    
    mutating func preStart() {
        unowned let ref = self.ref
        first = context.actorOf(name: "first") { context in
            Filter(context: context, prime: 2, client: ref)
        }
    }
    
    func childTerminated(_ child: ActorRef) {
        endTime = Date().timeIntervalSince1970
        print("Stop: \(Date())")
        print("Duration: \(endTime - startTime)")
        exit(0)
    }
    
    func receive(_ msg: SieveMessage) {
        switch msg {
        case .start:
            startTime = Date().timeIntervalSince1970
            print("Start: \(Date())")
            for i in 3..<max {
                first ! .number(i)
            }
            first ! .poisonPill
        case .number(let n): break
//            print(n)
        }
    }
    
    public func supervisorStrategy(error: Error) { }
    public func willStop() { }
    public func postStop() { }
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
root ! .start

sleep(300)

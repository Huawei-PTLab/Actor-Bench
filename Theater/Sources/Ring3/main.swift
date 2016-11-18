import Theater
import Foundation

// Messages
class Connect: Actor.Message {
    let partner: ActorRef
    
    init(_ partner: ActorRef, sender: ActorRef?) {
        self.partner = partner
        super.init(sender: sender)
    }
}
class Token: Actor.Message {
	let count: Int
	init(count: Int, sender: ActorRef?) {
		self.count = count
		super.init(sender: sender)
	}
}

// Global timer
var startTime: Double = 0.0
var endTime: Double = 0.0
var nNodes = 3
var nRounds = 10

class Passer: Actor {
	let nodeId: Int
	weak var partner: ActorRef! = nil

    required init(context: ActorCell, id: Int, partner: ActorRef? = nil) {
		self.nodeId = id
		self.partner = partner
		super.init(context: context)
	}

	override func receive(_ msg: Actor.Message) {
		switch(msg) {
        case let connect as Connect:
            self.partner = connect.partner
		case let token as Token:
            let count = token.count + 1
            if count >= nRounds {
                endTime = Date().timeIntervalSince1970
                print("Stop: \(Date())")
                print("Duration: \(endTime - startTime)")
                exit(0)
                // Tell the rest of the ring to stop
                partner ! PoisonPill(sender: this)
            } else {
                partner ! Token(count: count, sender: this)
            }
		default:
			print("Actor \(nodeId) got unexpected message: \(msg)")
		}
	}
    
    func close(partner: ActorRef) {
        self.partner = partner
    }
}

if let nodes = Int(CommandLine.arguments[1]) {
    nNodes = nodes
}
if let rounds = Int(CommandLine.arguments[2]) {
    nRounds = rounds
}
print("Ring size: \(nNodes)")
print("Number of rounds: \(nRounds)")
let system = ActorSystem(name: "Ring3")
var passers = [ActorRef]()
passers.append(system.actorOf(name: "Passer0") { context in
    Passer(context: context, id: 0)
    })
for i in 1..<nNodes {
    var passer = system.actorOf(name: "Passer\(i)") { context in
        Passer(context: context, id: i, partner: passers[i-1])
    }
    passers.append(passer)
}
passers[0] ! Connect(passers[nNodes - 1], sender: nil)

startTime = Date().timeIntervalSince1970
print("Start: \(Date())")
passers[0] ! Token(count: 0, sender: nil)
sleep(30)	// wait to complete

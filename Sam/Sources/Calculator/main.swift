import Sam
import Foundation
#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

protocol Expr {
	@discardableResult func compute() -> Int
	func toString() -> String
}
struct Add: Expr {
	let left: Expr
	let right: Expr
	func compute() -> Int { return left.compute() + right.compute() }
	func toString() -> String { return "( \(left.toString()) + \(right.toString()) )" }
}
struct Sub: Expr {
	let left: Expr
	let right: Expr
	func compute() -> Int { return left.compute() - right.compute() }
	func toString() -> String { return "( \(left.toString()) - \(right.toString()) )" }
}
struct Mul: Expr {
	let left: Expr
	let right: Expr
	func compute() -> Int { return left.compute() * right.compute() }
	func toString() -> String { return "( \(left.toString()) * \(right.toString()) )" }
}
struct Div: Expr {
	let left: Expr
	let right: Expr
	func compute() -> Int { 
		let rhs = right.compute()
		if rhs == 0 {
			print("illegal rhs: \(rhs)")
			exit(0)
		} else {
			return left.compute() / rhs
		}
	}
	func toString() -> String { return "( \(left.toString()) / \(right.toString()) )" }
}
struct Const: Expr {
	let value: Int
	func compute() -> Int { return value }
	func toString() -> String { return "\(value)" }
}

srandom(UInt32(Date().timeIntervalSince1970))
func getRand() -> Int {
    #if os(Linux)
        return random() % 10
    #else
        return Int(arc4random() % 10)
    #endif
}

func genRandomExpr(nOps: Int) -> Expr {
	if nOps == 0 {
		return Const(value: getRand())
	} else {
        let opType: Int
        #if os(Linux)
            opType = random() % 4
        #else
            opType = Int(arc4random() % 4)
        #endif
		switch opType {
		case 0:	return Add(left: Const(value: getRand()), right: genRandomExpr(nOps: nOps - 1))
		case 1: return Sub(left: genRandomExpr(nOps: nOps - 1), right: Const(value: getRand()))
		case 2:	return Mul(left: Const(value: getRand()), right: genRandomExpr(nOps: nOps - 1))
		case 3: return Div(left: genRandomExpr(nOps: nOps - 1), right: Const(value: getRand() + 1))
		default: print("Unexpected case"); exit(1)
		}
	}
}

// Global timer
var startTime: Double = 0.0
var endTime: Double = 0.0

func start() {
	print(Date())
	startTime = Date().timeIntervalSince1970
}
func end() {
	endTime = Date().timeIntervalSince1970
	print(Date())
}
func duration() {
	print("Duration: \(endTime - startTime)")
}

enum CalcMessage: Message {
    case start
    case stop(sender: KnownActorRef<Master>?)
    case request
    case resultCount(count: Int)
}

struct Master: Actor {
    unowned let actorContext: KnownActorCell<Master>
    var context: ActorCell {
        get { return actorContext }
    }
    
    typealias Message = CalcMessage
    
    let nSlaves: Int
    var count = 0
    var slaves = [KnownActorRef<Slave>]()
    var curSlave = 0
    let nExpressions: Int
    let nOperators: Int

    init(context: KnownActorCell<Master>, expressions: Int, operators: Int, slaves: Int) {
        self.actorContext = context
        self.nExpressions = expressions
        self.nOperators = operators
        self.nSlaves = slaves
    }
    
    mutating func receive(_ msg: Message) {
        switch(msg) {
        case .start:
            for i in 1...nSlaves {
                print("Slave \(i) created")
                let nOperators = self.nOperators
                slaves.append(context.actorOf(name: "slave\(i)", { (context: KnownActorCell<Slave>) in Slave(context: context, operators: nOperators)}))
            }
        case .request:
            slaves[curSlave] ! .request
            curSlave = (curSlave + 1) % nSlaves
        case .stop:
            for s in slaves {
                s ! Slave.Message.stop(sender: ref)
            }
        case .resultCount(let i):
            count += i
            if count == nExpressions {
                end()
                duration()
                exit(0)
            }
        }
    }
    
    public func supervisorStrategy(error: Error) { }
    public func preStart() { }
    public func willStop() { }
    public func postStop() { }
    public func childTerminated(_ child: ActorRef) { }
}

struct Slave: Actor {
    unowned let actorContext: KnownActorCell<Slave>
    var context: ActorCell {
        get { return actorContext }
    }

    typealias Message = CalcMessage
    
	var count = 0
	let nOperators: Int

    init(context: KnownActorCell<Slave>, operators: Int) {
        self.actorContext = context
		self.nOperators = operators
	}

	mutating func receive(_ msg: Message) {
		switch(msg) {
		case .request:
			count += 1
			let expr = genRandomExpr(nOps: nOperators)
			expr.compute()
		case .stop(let sender):
            sender! ! .resultCount(count: count)
		default:
			print("Unexpected message")
		}
	}
    
    public func supervisorStrategy(error: Error) { }
    public func preStart() { }
    public func willStop() { }
    public func postStop() { }
    public func childTerminated(_ child: ActorRef) { }
}

let nExpressions = Int(CommandLine.arguments[1])!
let nOperators = Int(CommandLine.arguments[2])!
let nSlaves = Int(CommandLine.arguments[3])!

func sequential() {
	start()
	for _ in 1...nExpressions {
		let expr = genRandomExpr(nOps: nOperators)
		expr.compute()
	}
	end()
	duration()
}

func actor() {
	let system = ActorSystem(name: "Calculator")
    let master = system.actorOf(name: "master", { (context: KnownActorCell<Master>) in Master(context: context, expressions: nExpressions, operators: nOperators, slaves: nSlaves) })
	master ! .start
	start()
	for _ in 1...nExpressions {
		master ! .request
	}
	master ! Master.Message.stop(sender: nil)
}

// sequential()
actor()
sleep(1000)	// wait to complete

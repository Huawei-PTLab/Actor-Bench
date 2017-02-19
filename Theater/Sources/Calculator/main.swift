import Theater
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

class Start: Actor.Message {}
class Stop: Actor.Message {}
class Request: Actor.Message {}
class ResultCount: Actor.Message {
	let count: Int
	init(count: Int, sender: ActorRef) {
		self.count = count
		super.init(sender: sender)
	}
}

class Master: Actor {
	let nSlaves: Int
	var count = 0
	var slaves: [ActorRef] = []
	var curSlave = 0
	let nExpressions: Int
	let nOperators: Int

    init(context: ActorCell, expressions: Int, operators: Int, slaves: Int) {
		self.nExpressions = expressions
		self.nOperators = operators
		self.nSlaves = slaves
        super.init(context: context)
	}

	override func receive(_ msg: Actor.Message) {
		switch(msg) {
		case is Start:
			for i in 1...nSlaves {
				print("Slave \(i) created")
                slaves.append(context.actorOf(name: "slave\(i)", { (context: ActorCell) in Slave(context: context, operators: self.nOperators)}))
			}
		case is Request:
			slaves[curSlave] ! Request(sender: this)
			curSlave = (curSlave + 1) % nSlaves
		case is Stop:
			for s in slaves {
				s ! Stop(sender: this)
			}
		case let i as ResultCount:
			count += i.count
			if count == nExpressions {
                count = count + 1 //More slaves will not cause double shutdown
				end()
				duration()
                // The right way to shut down the system is call shutdown()
                // Calling exit(0) is faster and doesn't matter in a benchmark
                // context.system.shutdown()
                exit(0)
			}
		default:
			print("Unexpected message")
		}
	}
}

class Slave: Actor {
	var count = 0
	let nOperators: Int

    init(context: ActorCell, operators: Int) {
		self.nOperators = operators
        super.init(context: context)
	}

	override func receive(_ msg: Actor.Message) {
		switch(msg) {
		case is Request:
			count += 1
			let expr = genRandomExpr(nOps: nOperators)
			expr.compute()
		case is Stop:
			msg.sender ! ResultCount(count: count, sender: this)
		default:
			print("Unexpected message")
		}
	}
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
    let master = system.actorOf(name: "master", { (context: ActorCell) in Master(context: context, expressions: nExpressions, operators: nOperators, slaves: nSlaves) })
	master ! Start(sender: nil)
	start()
	for _ in 1...nExpressions {
		master ! Request(sender: nil)
	}
	master ! Stop(sender: nil)
    _ = system.waitFor(seconds:1000) // wait to complete or timeout in 1000s
}

// sequential()
actor()

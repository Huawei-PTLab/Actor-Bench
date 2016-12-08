import Sam
import Foundation

enum Color: Int {
	case BLUE = 0
	case RED
	case YELLOW
	case FADED
}

enum ChameneoMessage: Message {
    case meet(from: KnownActorRef<Chameneo>, color: Color)
    case change(Color)
    case meetingCount(Int)
    case stop(sender: KnownActorRef<Mall>)
    case start
}

// Global timer
var startTime = 0.0
var endTime = 0.0

// Actors
struct Chameneo: Actor {
    unowned let actorContext: KnownActorCell<Chameneo>
    var context: ActorCell {
        get { return actorContext }
    }
    
    typealias ActorMessage = ChameneoMessage
    
	let mall: KnownActorRef<Mall>
	var color: Color
	let cid: Int
	var meetings = 0
    init(context: KnownActorCell<Chameneo>, mall: KnownActorRef<Mall>, color: Color, cid: Int) {
        self.actorContext = context
		self.mall = mall
		self.color = color
		self.cid = cid
	}

	mutating func receive(_ msg: ActorMessage) {
		switch(msg) {
		case .start:
            mall ! ChameneoMessage.meet(from: ref, color: color)
        case .meet(let from, let color):
			self.color = complement(color)
			self.meetings += 1
            let chameneo = from as! KnownActorRef<Chameneo>
			chameneo ! ChameneoMessage.change(self.color)
            self.mall ! ChameneoMessage.meet(from: ref, color: self.color)
        case .change(let color):
			self.color = color
			self.meetings += 1
            self.mall ! ChameneoMessage.meet(from: ref, color: self.color)
        case .stop(let sender):
			self.color = .FADED
			sender ! ChameneoMessage.meetingCount(self.meetings)
		default:
			print("Unexpected message")
		}
	}

	func complement(_ otherColor: Color) -> Color {
		switch(color) {
		case .RED:
			switch(otherColor) {
			case .RED: return .RED
			case .YELLOW: return .BLUE
			case .BLUE: return .YELLOW
			case .FADED: return .FADED
			}
		case .YELLOW:
			switch(otherColor) {
			case .RED: return .BLUE
			case .YELLOW: return .YELLOW
			case .BLUE: return .RED
			case .FADED: return .FADED
			}
		case .BLUE:
			switch(otherColor) {
			case .RED: return .YELLOW
			case .YELLOW: return .RED
			case .BLUE: return .BLUE
			case .FADED: return .FADED
			}
		case .FADED:
			return .FADED
		}
	}
    
    public func supervisorStrategy(error: Error) { }
    public func preStart() { }
    public func willStop() { }
    public func postStop() { }
    public func childTerminated(_ child: ActorRef) { }
}

struct Mall: Actor {
    unowned let actorContext: KnownActorCell<Mall>
    public var context: ActorCell {
        get { return actorContext }
    }
    
    typealias ActorMessage = ChameneoMessage
    
	var n: Int
	let numChameneos: Int
	var waitingChameneo: KnownActorRef<Chameneo>?
	var sumMeetings: Int = 0
	var numFaded: Int = 0

    init(context: KnownActorCell<Mall>, n: Int, numChameneos: Int) {
        self.actorContext = context
		self.n = n
		self.numChameneos = numChameneos
	}

	mutating func receive(_ msg: ActorMessage) {
		switch(msg) {
        case .start:
			print("Started: \(Date())")
			startTime = Date().timeIntervalSince1970
			for i in 0..<numChameneos {
                unowned let ref = self.ref
                let c = context.actorOf(name: "Chameneo\(i)", { context in Chameneo(context: context, mall: ref, color: Color(rawValue: (i % 3))!, cid: i) })
				c ! ChameneoMessage.start
			}
		case .meetingCount(let mcount):
			self.numFaded += 1
			self.sumMeetings += mcount
			if numFaded == numChameneos {
				endTime = Date().timeIntervalSince1970
				print("Stopped: \(Date())")
				print("Duration: \(endTime - startTime)")
				print("Sum meetings: \(self.sumMeetings)")	// should be double of n
				exit(0)
			}
		case .meet(let from, let color):
			if self.n > 0 {
				if let waiting = self.waitingChameneo {
					n -= 1
                    waiting ! ChameneoMessage.meeting(from: from, color: color)
					self.waitingChameneo = nil
				} else {
					self.waitingChameneo = from //msg.sender!
				}
			} else {
				if let waiting = self.waitingChameneo {
                    waiting ! ChameneoMessage.stop(sender: ref)
				}
                from ! ChameneoMessage.stop(sender: ref)
			}
		default:
			print("Unexpected Message")
		}
	}
    
    public func supervisorStrategy(error: Error) { }
    public func preStart() { }
    public func willStop() { }
    public func postStop() { }
    public func childTerminated(_ child: ActorRef) { }
}

let nChameneos = Int(CommandLine.arguments[1])!
let nHost = Int(CommandLine.arguments[2])!
let system = ActorSystem(name: "chameneos")
let mallActor = system.actorOf(name: "mall", { (context: KnownActorCell<Mall>) in Mall(context: context, n: nHost, numChameneos: nChameneos) })
mallActor ! ChameneoMessage.start
sleep(6000)

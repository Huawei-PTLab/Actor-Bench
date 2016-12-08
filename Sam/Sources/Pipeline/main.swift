import Sam
import Foundation


// Global timer
var startTime = 0.0	// set before sending the first message to downloadActor
var endTime = 0.0	// set in WriteActor

enum PipelineMessage: Message {
    case payload(String)
    case stop
}

struct DownloadActor: Actor {
    unowned let actorContext: KnownActorCell<DownloadActor>
    var context: ActorCell {
        get { return actorContext }
    }
    
    typealias Message = PipelineMessage

	let indexer: KnownActorRef<IndexActor>
    init(context: KnownActorCell<DownloadActor>, indexer: KnownActorRef<IndexActor>) {
        self.actorContext = context
		self.indexer = indexer
	}
    
	func receive(_ msg: Message) {
		switch(msg) {
		case .payload(let payload):
			let newPayload = payload.replacingOccurrences(of: "Requested", with: "Downloaded")
			indexer ! .payload(newPayload)
		case .stop:
			print("Downloader stopped!")
			indexer ! .stop
		}
	}
    
    public func supervisorStrategy(error: Error) { }
    public func preStart() { }
    public func willStop() { }
    public func postStop() { }
    public func childTerminated(_ child: ActorRef) { }
}

class IndexActor: Actor {
    unowned let actorContext: KnownActorCell<IndexActor>
    var context: ActorCell {
        get { return actorContext }
    }
    
    typealias Message = PipelineMessage
	let writer: KnownActorRef<WriteActor>
    
    init(context: KnownActorCell<IndexActor>, writer: KnownActorRef<WriteActor>) {
        self.actorContext = context
		self.writer = writer
	}
	
    func receive(_ msg: Message) {
		switch(msg) {
		case .payload(let payload):
			let newPayload = payload.replacingOccurrences(of: "Downloaded", with: "Indexed")
			writer ! .payload(newPayload)
		case .stop:
			print("Indexer stopped!")
			writer ! .stop
		}
	}
    
    public func supervisorStrategy(error: Error) { }
    public func preStart() { }
    public func willStop() { }
    public func postStop() { }
    public func childTerminated(_ child: ActorRef) { }
}

class WriteActor: Actor {
    unowned let actorContext: KnownActorCell<WriteActor>
    var context: ActorCell {
        get { return actorContext }
    }
    
    typealias Message = PipelineMessage
    
    init(context: KnownActorCell<WriteActor>) {
        self.actorContext = context
    }
    
	func receive(_ msg: Message) {
		switch(msg) {
		case .payload(let payload):
			let _ = payload.replacingOccurrences(of: "Indexed", with: "Written")
			// uncomment this to examine results
			// print(newPayload)
		case .stop:
			print("Writer stopped!")
			endTime = Date().timeIntervalSince1970
			print("Stop: \(Date())")
			print("Duration: \(endTime - startTime)")
			exit(0)
		}
	}
    
    public func supervisorStrategy(error: Error) { }
    public func preStart() { }
    public func willStop() { }
    public func postStop() { }
    public func childTerminated(_ child: ActorRef) { }
}

let nRequests = Int(CommandLine.arguments[1])!
let system = ActorSystem(name: "pipeline")
let writeActor = system.actorOf(name: "writer", { context in WriteActor(context: context) })
let indexActor = system.actorOf(name: "indexer", { context in IndexActor(context: context, writer: writeActor) })
let downloadActor = system.actorOf(name: "downloader", { context in DownloadActor(context: context, indexer: indexActor) })
startTime = Date().timeIntervalSince1970
print("Start: \(Date())")
for i in 1...nRequests {
	downloadActor ! .payload("Requested \(i)")
}
downloadActor ! .stop
sleep(100)	// wait to complete

import java.util.Calendar
import akka.actor._

object Ring {
  val system = ActorSystem("Ring")
  var startTime: Long = 0
  var endTime: Long = 0

  def main(args: Array[String]): Unit = {
    val numNodes = args(0).toInt
    val numRounds = args(1).toInt
    val nodes =
      for (i <- 0 until numNodes) yield system.actorOf(Props(classOf[RingNode], i, numRounds), "Node" + i)
    for (i <- 0 until numNodes) nodes(i) ! Connect(nodes((i + 1) % numNodes))
    nodes(0) ! Start
  }

  case object Start
  case object Stop
  case class Connect(next: ActorRef)
  case class Token(goal: Int, lapsRemaining: Int)

  class RingNode(val nodeId: Int, val numRounds: Int) extends Actor {
    var nextNode: ActorRef = context.system.deadLetters

    def receive = {
      case Connect(next: ActorRef) =>
        // println(s"Actor $nodeId is connecting to ${next.path}")
        nextNode = next

      case Start =>
        println("Start: \t" + Calendar.getInstance().getTime)
        Ring.startTime = System.currentTimeMillis()
        nextNode ! Token(nodeId, numRounds)

      case Token(goal, lapsRemaining) =>
        if (goal == nodeId) {
          if (lapsRemaining == 1) {
            Ring.endTime = System.currentTimeMillis()
            println("Stop: \t" + Calendar.getInstance().getTime)
            println(s"Elapsed time: ${(Ring.endTime - Ring.startTime) / 1000.0}s")
            system.shutdown()
          } else {
            nextNode ! Token(goal, lapsRemaining - 1)
          }
        } else {
          nextNode ! Token(goal, lapsRemaining)
        }
    }
  }
}

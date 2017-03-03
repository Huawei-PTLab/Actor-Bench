# Setup

Install [sbt]("http://www.scala-sbt.org/0.13/docs/Setup.html") and [scala]("http://www.scala-lang.org/download/install.html"). On Ubuntu, this can be done with the following commands:

    echo "deb https://dl.bintray.com/sbt/debian /" | sudo tee -a /etc/apt/sources.list.d/sbt.list
    sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 2EE0EA64E40A89B84B2DF73499E82A75642AC823
    sudo apt-get update
    sudo apt-get install sbt scala

# Usage

    sbt "run-main Ring <ring_size> <num_of_rounds>"
    sbt "run-main BusyRing <ring_size> <num_of_messages>"
    sbt "run-main Fork <depth>"
    sbt "run-main TreeMsg <depth> <num_msg>"
    sbt "run-main Pipeline <num_request>"
    sbt "run-main Chameneos <num_cham> <num_host>"
    sbt "run-main Calculator <num_expressions> <num_operators> <num_workers>"


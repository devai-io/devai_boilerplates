# rust-pipeline

This tutorial demonstrates how build and deploy Rust applications efficiently using Docker caching mechanisms and **[cargo-chef](https://crates.io/crates/cargo-chef)**.  

To continue, you must have [Docker](https://docs.docker.com/engine/) and [docker-compose](https://docs.docker.com/compose/) installed, besides the Rust toolchain. 

As a bonus, this tutorial show how to use pre-built binaries as opposed to building it on a CD/CI server, for low cost purposes due to the expensive and time-consuming process of Rust builds.

**Note**: A couple changes are required to adapt this strategy into your own projects:
- The path **C:/dev/git/rust-pipeline** should be replaced in **docker-compose.yml**.
- The name **rust-pipeline** must be changed in the commands and Dockerfiles in **./docker/** to reflect your application name.

**Note:** To deploy and run the application on the server using the benefits of cargo-chef caching, all needed is to execute **docker-compose up**.

### Running the application locally

    docker-compose up

Besides starting the application, this will compile the binary required by the next steps.
Alternatively, this could be done without docker-compose and without running it locally:

    docker build -t rust-pipeline -f docker/Dockerfile .
    mkdir bin
    docker run -it --rm -v C:/dev/git/rust-pipeline:/tmp/ rust-pipeline-pre cp /app/rust-pipeline /tmp/bin/


### Copy binary out of container

    mkdir bin
    docker-compose run app cp /app/rust-pipeline /tmp/bin/

***Note***: At this stage, the binary **./bin/rust-pipeline** should be committed to your repository, then checked out on the target machine.

### Running the application on the target machine

    docker-compose -f docker-compose.precompiled.yml up


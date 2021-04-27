# rosbox

A Docker image for the quick setup of reproducible ROS environments meant originally for the Automation and Robotics Research Group (ARG) of the University of Luxembourg.

Originally meant for utilization by the ARG group of the University of Luxembourg.

## Requirements

Install [Rocker](https://github.com/osrf/rocker):

```bash
sudo apt install python3 && python3-rocker
```

## Building the image

In order to build the image, run:

```bash
docker build -t rosbox:latest .
```

This only needs to be performed once. After the image is built, it will be available within the local Docker registry.

Note that this can take some time.

## Boxing a ROS workspace

Run the Rosbox container from within your project root directory:

```bash
docker run --rm -ti \
    --name rosbox-1 \
    --hostname rosbox \
    -p 8080:8080 \
    -p 3000:3000 \
    -p 9001:9001 \
    -p 9876:9876 \
    -p 11301:11301 \
    -v /tmp/.x11-unix \
    -v ~/.ssh:/home/rosbox/.ssh:ro \
    -v $(pwd):/home/rosbox/workspace \
    rosbox
```

- To access Theia IDE, open http://localhost:3000
- To access the container's X server, open http://localhost:8080
- To access `supervisord` UI, open http://localhost:9001
- The ROS master is exposed via port 11301 

## Accessing Rosbox

If you have any Rosbox containers running, you can access it with the following command: 

```
docker container exec -it rosbox-1 /bin/bash
```

You will then have access to a shell within the container, from where you can e.g., start/stop ROS nodes, and do whatever you want.

## Contributing
- Fork the project on GitHub
- Clone your fork: git clone https://github.com/your_username/rosbox
- Create a new branch: git checkout -b my-new-feature
- Make changes and stage them: git add .
- Commit your changes: git commit -m 'Add some feature'
- Push to the branch: git push origin my-new-feature
- Create a new pull request

## Roadmap
- [ ] Break Rosbox into multiple modules
- [ ] Add GPU support 
- [ ] Shrink image

## License

Rosbox is released under the Apache 2.0 license.


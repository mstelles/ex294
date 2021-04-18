#!/usr/bin/env python3

import docker
client = docker.client.from_env()
for container in client.containers.list():
    print(container.id)

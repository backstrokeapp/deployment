# Backstroke Deployment

Backstroke is a Github bot to keep repository forks up to date with their upstream. While it used to
be a monolith, it's now a number of smaller microservices.

![Services.png](Services.png)

- [server](https://github.com/backstrokeapp/server), the service that handles User auth and Link
  CRUD. In addition, this service adds link operations to a queue when a link is out of date.
- [worker](https://github.com/backstrokeapp/worker), a worker that eats off the queue of link
  operations, performs the operations, and stores the results.
- [legacy](https://github.com/backstrokeapp/legacy), a service that maintains backwards
  compatibility for legacy features like Backstroke classic and forwarding of old api requests to
  the `server` service.
- [dashboard](https://github.com/backstrokeapp/dashboard), a react-based frontend to the api
  provided by the `server` service. Mainly handles logging in and Link CRUD.
- [www](https://github.com/backstrokeapp/www), the Backstroke website found at
  https://backstroke.co.

# Deployment
Deployment is orchestrated with `docker-compose`, which is powered by
[docker](https://docs.docker.com/engine/docker-overview/) containers.  The `docker-compose.yml` file
in the root of this repository provides some default settings that hold true no matter the
environment Backstroke is being deployed in. To deploy Backstroke, kick off docker-compose
with a command similar to `docker-compose -f docker-compose.yml -f my-environment-docker-compose.yml
up`. In a nutshell, this combines the two configuration files together which allows you to customize
each service without modifying the main `docker-compose.yml`. Depending on the environment
Backstroke is being deployed into, the contents of the second docker-compose file will vary.

## Development
In development, we want to run all services locally and make it as easy as possible to reset the
state of the entire application.

### Prerequisites
- A Github [Personal access token](https://github.com/settings/tokens) for the user that will be
  making pull requests. 
- A Github [oauth application](https://github.com/settings/developers) for Backstroke to use to
  login users. The callback url should be `http://localhost:8000/auth/github/callback`.

1. Copy this example `development-docker-compose.yml` file into your project:

```yml
version: "3.1"

services:

  # A database for the `server` service
  database:
    image: library/postgres
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: docker
      POSTGRES_PASSWORD: docker
      POSTGRES_DB: docker

  worker:
    depends_on:
      - redis
    # Create mock pull requests.
    # Remove `--pr mock` if you want to make actual pull requests (make sure you know what you're
    # doing!).
    command: yarn start -- --pr mock
    environment:
      REDIS_URL: redis://redis:6379
      GITHUB_TOKEN: <insert github personal access token here>

  server:
    depends_on:
      - database
    environment:
      DEBUG: backstroke:*

      DATABASE_URL: postgres://docker:docker@database:5432/docker
      DATABASE_REQUIRE_SSL: 'false'

      GITHUB_TOKEN: <insert github personal access token here>
      GITHUB_CLIENT_ID: <insert github client id here>
      GITHUB_CLIENT_SECRET: <insert github client secret here>
      GITHUB_CALLBACK_URL: <insert gitthub oauth callback here>
      SESSION_SECRET: "backstroke development session secret"
      CORS_ORIGIN_REGEXP: .*

      # The locations of a couple other services
      APP_URL: http://localhost:3000
      API_URL: http://localhost:8000
      ROOT_URL: https://backstroke.co

  legacy:
    environment:
      GITHUB_TOKEN: <insert github personal access token here>

  # Development version of the dashboard.
  dashboard:
    image: backstroke/dashboard
    ports:
      - '3000:3000'
    environment:
      NODE_ENV: development
      PORT: 3000


volumes:
  database:
```

2. Run `docker-compose -f docker-compose.yml -f development-docker-compose.yml up`.

3. Migrate the database. [Here's how](#migrate-database).

4. Visit http://localhost:8000 for the `server` service, http://localhost:3000 for the `dashboard`
   service, or http://localhost:4000 for the `legacy` service. These ports were defined in the
   [first docker-compose file](https://github.com/backstrokeapp/deployment/blob/master/docker-compose.yml).

### Live-reloading
In the above configuration, changing server code locally won't restart the service. If you'd like
for the service to restart when you save your code, two things are required:

1. Change the `command` of the service to use [nodemon](https://npmjs.com/nodemon).
2. Mount your code into the service as a volume

Here's an example for the `server` service above:
```yml
...
server:
  # 1. Use nodemon.
  command: yarn start-dev
  # 2. Mount code into container.
  volumes:
    - "./path/to/my/code/from/this/repository:/app"
  environment:
    ...
...
```
All node-based services should have a `start-dev` npm task associated with them. If not, open an
issue.

### A note on the worker
The worker will make **real, live github pull requests** by default. Don't spam other people's
repositories! However, there [is a flag that can be enabled to cause the worker to make mock pull
requests instead of real ones](https://github.com/backstrokeapp/worker#arguments).

### Running outside Docker
Sometimes, you'd like to test a service in isolation. Using docker-compose isn't really all that
helpful in this case. If docker-compose isn't helpful, don't feel like you have to use it.

# Production
In production, we use a very similar configuration to development, but with a few key differences:
- The database isn't hosted in a container, it's external and linked into the project.
- All services have a `restart: always` section to ensure that they will be restarted if they were
  to crash.
- Also, we host another container used to ship logs to an instance of the ELK stack (currently
  through logz.io) though this isn't required.

Since production deployments can change based on many 3rd-party factors, there isn't an example in
this section. Most likely you should be able to start with the development configuration and talor
it to your needs.

# Tasks
When hacking on Backstroke, here are a few tasks that are handy to be able to accomplish when
debugging a problem.

## Show all webhook operations in the queue
```
docker ps
# Note down the container id for redis
docker exec -it <CONTAINERID> redis-cli
> HGETALL rsmq:webhookQueue:Q
```
This list also contains statistics, so it's a bit of a pain to read. But all the items that are
long, random ids are the items in the queue.

## Inspect all complete webhook operation statuses
```
docker ps
# Note down the container id for redis
docker exec -it <CONTAINERID> redis-cli
> KEYS webhook:status:*
> GET webhook:status:myoperationid
```

## Tail logs for a service
```
docker ps
# Note down the container id for the service you want
docker logs -f <CONTAINERID>
```

## Migrate database (in development)
```
docker ps
# Note down the container id for the server
docker exec -it <CONTAINERID> yarn migrate 
```

## Manually run the webhook timer
Typically, this job runs about every 10 minutes and adds new webhook operations to the queue. If
you'd like to run it on your own (for development reasons), try this:
```
docker ps
# Note down the container id for the server
docker exec -it <CONTAINERID> yarn manual-job
```

## Open a node shell connected to the database
See [here](https://github.com/backstrokeapp/server/blob/master/CONTRIBUTING.md) for a list of values
present in this shell, but the TL;DR is that it's all database models and constructs for interacting
with redis.
```
docker ps
# Note down the container id for the server
docker exec -it <CONTAINERID> yarn shell
```

# Testing

Automated tests for the docker-postgres-snapshot image.

```bash
./run-tests.sh
```

The runner builds the image, starts PostgreSQL 15 to 18, runs the scenarios, restores the dumps into empty servers, and cleans up. Set `BUILD_NETWORK=host` if containers cannot resolve the Alpine mirrors during the build.

Full documentation: [Running Tests](https://jacobsanford.github.io/docker-postgres-snapshot/1.x/running-tests/)

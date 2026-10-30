# Testing

Automated tests for the docker-postgres-snapshot image.

```bash
./run-tests.sh
```

The runner builds the image, starts PostgreSQL 17 and 18, runs every scenario, restores the dumps into empty servers, and cleans up. Set `BUILD_NETWORK=host` if containers cannot resolve the Alpine mirrors during the build.

Full documentation: [Running Tests](https://jacobsanford.github.io/docker-postgres-snapshot/1.x/running-tests/)

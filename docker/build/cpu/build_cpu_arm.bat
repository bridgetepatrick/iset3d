docker buildx build --platform=linux/arm64/v8 -f Dockerfile_cpu_arm --tag digitalprodev/pbrt-v4-cpu-arm .
docker push digitalprodev/pbrt-v4-cpu-arm:latest



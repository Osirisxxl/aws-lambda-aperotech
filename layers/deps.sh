mkdir dist
docker build . -t deps

docker run -v $PWD/dist:/mnt -it --entrypoint "/bin/bash" deps

cp /bin/ffmpeg /mnt/ffmpeg


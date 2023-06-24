

# Data Schema for Docker Containers

In DB:

 - docker_tags
   - name: string
   - dockerfile: text
   - build operation: Write file, run docker build -t ... .

From Docker API:

 - Images
 - Containers



# Testing sequence

Before:

 - Image includes all packages / software installs.
 
At execute time:

 - Create container from image with driver command set.
 - Unpack driver tarball.
 - Unpack student tarball.
 - Unpack grading tarball.
 - Run driver.

#!/bin/sh
red=$(tput setaf 1)
green=$(tput setaf 2)
reset=$(tput sgr0)
UBlack='\033[4;30m'
On_Red='\033[41m'
# shellcheck disable=SC2154
# echo "Do you have remote origin Y/N"

#Functions start from here in order



#Will init the dir if it is not.
init_repo() {
    git_global_config=$(git config --global user.name)

    if [ -z "$git_global_config" ]; then
        git config --global user.name "$(whoami)"
    fi

    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git init
        git branch -m main 
    fi
}


# Will add remote if it is not.
add_remote() {
    if ! git remote | grep -q origin; then
        echo "Paste the http or ssh link:"
        read origin_link

        git remote add origin $origin_link
    fi
}

# Will check for projects type  and run it.
check_project() {

    if [ -f "docker-compose.yml" ]; then
        docker-compose up --build

    elif [ -f "package.json" ]; then
        echo "This is a Node.js project."
        npm install
        npm run dev

    elif [ -f "manage.py" ]; then
        if [ -f "requirements.txt" ]; then
            pip install -r requirements.txt
        fi
        echo "This is a Django project."
        python manage.py migrate
        python manage.py runserver

    elif
        [ -f "composer.json" ]
    then
        echo "This is a PHP project."
        php artisan serve
        if [ -f "database/migrations/*.php" ]; then
            echo "Migrations found. Running migrations..."
            php artisan migrate
        fi

    elif jq '.dependencies | has("@angular/core")' package.json; then
        echo "This is an Angular project."
        npm i
        ng serve

    else
        echo "Could not determine project type."
    fi

}

# Will create simple pre commit for every type of project.(Very simple .pre-commit hooks are used you can install flask pretify also.)
PreCommitHooks() {

    if ! type "pre-commit" >/dev/null; then
        echo "Installing pre-commit..."
    fi

    if [ -d ".git" ]; then
        echo "Creating pre-commit hook in .git/hooks"
        mkdir -p .git/hooks
        if [ -f "package.json" ]; then
            echo "This is a Node.js project."
            echo "Creating pre-commit hook to run tests..."
            echo "npm test --no-watch --browers ChromeHeadless" > .git/hooks/pre-commit
            chmod +x .git/hooks/pre-commit
        elif [ -f "manage.py" ]; then
            echo "This is a Django project."
            echo "Creating pre-commit hook to run tests..."
            echo "python3 manage.py test" > .git/hooks/pre-commit
            chmod +x .git/hooks/pre-commit
        elif [ -f "docker-compose.yml" ]; then
            echo "This is a Docker Compose project"
            echo "Creating pre-commit hook to run tests..."
            echo "docker-compose up --build" > .git/hooks/pre-commit
            chmod +x .git/hooks/pre-commit
        elif [ -f "composer.json" ]; then
            echo "This is a PHP project."
            echo "Creating pre-commit hook to run tests..."
            echo "phpunit" > .git/hooks/pre-commit
            chmod +x .git/hooks/pre-commit
        elif jq '.dependencies | has("@angular/core")' package.json && echo "This is an Angular project." || echo "jq command failed"; then
            export CHROME_BIN=/usr/bin/chromium-browser
            echo "Creating pre-commit hook to run tests..."
            echo "ng test --no-watch --browsers ChromeHeadless" > .git/hooks/pre-commit
            chmod +x .git/hooks/pre-commit
        else
            echo "Could not determine project type."
        fi
    else
        echo "This is not a git repository"
    fi
}


#Creates only and image will not create a docker-compose file.

dockerize_project() {

    if [ -f "package.json" ]; then
        echo "This is a Node.js project. Creating Dockerfile..."
        echo "FROM node:14" >Dockerfile
        echo "WORKDIR /app" >>Dockerfile
        echo "COPY package*.json ./" >>Dockerfile
        echo "RUN npm install" >>Dockerfile
        echo "COPY . . " >>Dockerfile
        echo "EXPOSE 3000" >>Dockerfile
        echo "CMD [\"npm\", \"start\"]" >>Dockerfile
        echo "Dockerfile created for Node.js project."


    elif [ -f "manage.py" ]; then
        echo "This is a Django project. Creating Dockerfile..."
        echo "FROM python:3.9" >Dockerfile
        echo "WORKDIR /app" >>Dockerfile
        echo "COPY requirements.txt . " >>Dockerfile
        echo "RUN pip install -r requirements.txt" >>Dockerfile
        echo "COPY . . " >>Dockerfile
        echo "EXPOSE 8000" >>Dockerfile
        echo "CMD [\"python\", \"manage.py\", \"runserver\", \"0.0.0.0:8000\"]" >>Dockerfile

    elif [ -f "composer.json" ]; then
        echo "This is a PHP project. Creating Dockerfile..."
        echo "FROM php:7.4-fpm" >Dockerfile
        echo "WORKDIR /app" >>Dockerfile
        echo "COPY composer.json . " >>Dockerfile
        echo "RUN php composer.phar install" >>Dockerfile
        echo "COPY . . " >>Dockerfile
        echo "EXPOSE 9000" >>Dockerfile
        echo "CMD [\"php-fpm\"]" >>Dockerfile
        echo "Dockerfile created for PHP project."

    elif
        jq '.dependencies | has("@angular/core")' package.json
    then
        echo "This is an Angular project."
        echo "FROM node:14" >Dockerfile
        echo "WORKDIR /app" >>Dockerfile
        echo "COPY package*.json ./" >>Dockerfile
        echo "RUN npm install" >>Dockerfile
        echo "COPY . . " >>Dockerfile
        echo "EXPOSE 4200" >>Dockerfile
        echo "CMD [\"npm\", \"start\"]" >>Dockerfile
        echo "Dockerfile created for Angular project."
    else
        echo "Could not determine project type."

    fi

}

productionSettings(){
mkdir .github/workflows
touch .github/workflows/dcoker-publish.yml
echo "name: Docker

# This workflow uses actions that are not certified by GitHub.
# They are provided by a third-party and are governed by
# separate terms of service, privacy policy, and support
# documentation.

on:
  schedule:
    - cron: '20 11 * * *'
  push:
    branches: [ "main" ]
    # Publish semver tags as releases.
    tags: [ 'v*.*.*' ]
  pull_request:
    branches: [ "main" ]

env:
  # Use docker.io for Docker Hub if empty
  REGISTRY: ghcr.io
  # github.repository as <account>/<repo>
  IMAGE_NAME: ${{ github.repository }}


jobs:
  build:

    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      # This is used to complete the identity challenge
      # with sigstore/fulcio when running outside of PRs.
      id-token: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v3

      # Install the cosign tool except on PR
      # https://github.com/sigstore/cosign-installer
      - name: Install cosign
        if: github.event_name != 'pull_request'
        uses: sigstore/cosign-installer@f3c664df7af409cb4873aa5068053ba9d61a57b6 #v2.6.0
        with:
          cosign-release: 'v1.11.0'


      # Workaround: https://github.com/docker/build-push-action/issues/461
      - name: Setup Docker buildx
        uses: docker/setup-buildx-action@79abd3f86f79a9d68a23c75a09a9a85889262adf

      # Login against a Docker registry except on PR
      # https://github.com/docker/login-action
      - name: Log into registry ${{ env.REGISTRY }}
        if: github.event_name != 'pull_request'
        uses: docker/login-action@28218f9b04b4f3f62068d7b6ce6ca5b26e35336c
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      # Extract metadata (tags, labels) for Docker
      # https://github.com/docker/metadata-action
      - name: Extract Docker metadata
        id: meta
        uses: docker/metadata-action@98669ae865ea3cffbcbaa878cf57c20bbf1c6c38
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}

      # Build and push Docker image with Buildx (don't push on PR)
      # https://github.com/docker/build-push-action
      - name: Build and push Docker image
        id: build-and-push
        uses: docker/build-push-action@ac9327eae2b366085ac7f6a2d02df8aa8ead720a
        with:
          context: .
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max


      # Sign the resulting Docker image digest except on PRs.
      # This will only write to the public Rekor transparency log when the Docker
      # repository is public to avoid leaking data.  If you would like to publish
      # transparency data even for private images, pass --force to cosign below.
      # https://github.com/sigstore/cosign
      - name: Sign the published Docker image
        if: ${{ github.event_name != 'pull_request' }}
        env:
          COSIGN_EXPERIMENTAL: "true"
        # This step uses the identity token to provision an ephemeral certificate
        # against the sigstore community Fulcio instance.
        run: echo "${{ steps.meta.outputs.tags }}" | xargs -I {} cosign sign {}@${{ steps.build-and-push.outputs.digest }}"> dcoker-publish.yml






}



# Will build and tag the image here.

build_image() {
    echo "Type Your version (MAJOR.MINOR.PATCH):"
    read version

    echo "Please type the image name:"
    read imagename 

    if [ ! -f "Dockerfile" ]; then
        echo "Dockerfile not found, creating..."
        dockerize_project
    fi

    echo "Checking for existing image..."
    if sudo docker images | awk '{print $1}' | grep -q $imagename; then
        echo "Image already exists, updating..."
        # Stop and remove the existing container
        current_dir = $(basename"$(pwd)")
        sudo docker stop $current_dir-container
        sudo docker rm $current_dir-container
        #pull the latest image
        sudo docker pull $imagename:$version
        # Run the updated image
        sudo docker run --name $current_dir-container -d $imagename:$version
    else
        echo "Building new image..."
        sudo docker build -t $imagename:$version .
        # Build new container
        current_dir = $(basename"$(pwd)")
        sudo docker run --name $current_dir-container -d $imagename:$version

    fi
}



# Will pull repo while identifying the project installing and running the project.

pull_repo() {
    echo "Type Your origin Branch:"
    read branch
    git pull origin $branch
    if [ $? -ne 0 ]; then
        git pull origin $branch --rebase
        if [ $? -ne 0 ]; then
            git rebase origin master
            git mergetool
            git rebase --continue
            if [ $? -ne 0 ]; then
                echo "There were merge conflicts. Resolving conflicts now..."
                git status
                git mergetool
                git add .
                git rebase --continue
                if [ $? -ne 0 ]; then
                    echo "Merging failed, please resolve conflicts and try again."
                else
                    echo "Type the branch you want to merge:"
                    read merge_branch
                    git diff $branch $merge_branch
                    echo "Do you want to continue with merging ? (y/n)"
                    read choice
                    if [ $choice == "y" ]
                    then
                      git merge $merge_branch
                      if [ $? -ne 0 ]; then
                            echo "Merging failed, please resolve conflicts and try again."
                      else
                            git add .
                            system_username=$(whoami)
                            current_date=$(date +"%d/%m/%Y %T")
                            echo "Type Your Commit message:"
                            read varname
                            remote_url=$(git remote -v | grep -m1 "^origin" | awk '{print $2}')
                            project_name=$(echo $remote_url | awk -F[/:] '{print $4}')
                            git commit -m "by $system_username on $current_date with message:$varname, Project:$project_name"
                            check_project
                      fi
                    else
                      echo "Merging Aborted"
                    fi
                fi
            fi
        fi
    fi
}

# Will push the repo use commit formatter use pre commits and will also dockerize and build the image before deployment.

push_repo() {
    git fetch origin
    git status
    
   if [ "$(git status)" == "Your branch is behind 'origin/<branch>' by <n> commits, and can be fast-forwarded." ]; then
        echo "Your local branch is behind the remote, please pull before pushing"
        echo "Type Your origin Branch:"
        read branch
        git pull origin $branch
        if [ $? -ne 0 ]; then
            git pull origin $branch --rebase
            git rebase origin master
            git mergetool
            git rebase --continue
            if [ $? -ne 0 ]; then
                echo "There were merge conflicts. Resolving conflicts now..."
                git status
                git mergetool
                git add .
                git rebase --continue
                if [ $? -ne 0 ]; then
                    echo "Merging failed, please resolve conflicts and try again."
                else
                    git add .
                    system_username=$(whoami)
                    current_date=$(date +"%d/%m/%Y %T")
                    echo "Type Your Commit message:"
                    read varname
                    remote_url=$(git remote -v | grep -m1 "^origin" | awk '{print $2}')
                    project_name=$(echo $remote_url | awk -F[/:] '{print $4}')
                    git commit -m "by $system_username on $current_date with message:$varname, Project:$project_name"
                    check_project
                fi
            fi
        fi
    fi
    git add .
    PreCommitHooks 
    system_username=$(whoami)
    current_date=$(date +"%d/%m/%Y %T")
    echo "Type Your Commit message:"
    read varname
    git commit -m "by $system_username on $current_date with message:$varname "
    build_image
    echo "Type Your Branch:"
    read Branch
    git push origin $Branch
    if [$? -ne 0]; then
        echo "Push failed, trying force push"
        git push -f origin $Branch

        if [$? -ne 0]; then
            echo"Force push also failed"
        else
            echo"Force push successful"
            fi
    else
        echo "Git push completed"
        echo "Type Your version (MAJOR.MINOR.PATCH):"
        read version
        git tag -a $version -m "version $version"
        git push origin $version
        echo "Build tag pushed successfully"
    fi
}


# Main script begins here tried to use VT file but not going well so thought echo some characters directly not effiecnt but LOL


# touch .welcome.vt
echo "
[2J
(B
[9;10H#6(0       aa
(B[10;10H                   ____|____
[11;10H                  /_________\
[12;10H         ________/_I_I_I_I_I_\________
[13;10H         |_|_|_|_| I I I I I |_|_|_|_|
[14;10H         | O  O  | | | | | | |  O  O |
[15;10H         | O  O  | | | | | | |  O  O |
[16;10H         | O  O  | | | | | | |  O  O |--push push .
[17;10H         |_______I_I_I_I_I_I_I_______|

[19;10H            [Welcome to git shell ]" 


init_repo

add_remote
if [ "$(uname)" = "Linux" ]; then
    # install necessary packages for Linux
    sudo apt-get install toilet
    sudo apt-get install docker
    sudo apt-get pre-commit
    sudo apt install jq
elif [ "$(uname)" = "Darwin" ]; then
    # install necessary packages for Mac
    brew install toilet
    brew install docker
    brew install pre-commit
    brew install jq
elif [ "$(uname)" = "Windows" ]; then
    # install necessary packages for Windows
    choco install toilet
    choco install docker-desktop
    choco install pre-commit
    choco install jq
fi


toilet -F metal "Welcome to git shell"

echo "${red}Do You want to pull or push$:"
read Code

if [ $Code = pull ]; then
    echo = "
[2J
(B
[9;10H#6(0       aa
(B[10;10H                   ____|____
[11;10H                  /_________\
[12;10H         ________/_I_I_I_I_I_\________
[13;10H         |_|_|_|_| I I I I I |_|_|_|_|
[14;10H         | O  O  | | | | | | |  O  O |
[15;10H         | O  O  | | | | | | |  O  O |
[16;10H         | O  O  | | | | | | |  O  O |--push push ."\n
   
        echo ="

[14;45H   O    
[15;45H  /|\_ ...........Pulling......
[16;45H | |   
[17;45H _/ \  
[18;45H'    |_



    "

    pull_repo

elif

    [ $Code = push ]
then

    clear

    echo = "
[2J
(B
[9;10H#6(0       aa
(B[10;10H                   ____|____
[11;10H                  /_________\
[12;10H         ________/_I_I_I_I_I_\________dialog --menu 
[13;10H         |_|_|_|_| I I I I I |_|_|_|_|
[14;10H         | O  O  | | | | | | |  O  O |
[15;10H         | O  O  | | | | | | |  O  O |
[16;10H         | O  O  | | | | | | |  O  O |--push push .
[17;10H         |_______I_I_I_I_I_I_I_______|"

    echo "

[14;45H   O      O                
[15;45H  /|\_   /|\_  ..........Pushing......
[16;45H | |          
[17;45H _/ \  
[18;45H'    |_



    "
    push_repo

fi

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
        python manage.py run server

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

    # if ! type "pre-commit" >/dev/null; then
    #     echo "Installing pre-commit..."
       

    # elif [ -f ".git/hooks/pre-commit" ]; then
    #     echo "pre-commit hook already exists, skipping creation."
    # else

    if [ -f "package.json" ]; then
        echo "This is a Node.js project."
        echo "Creating pre-commit hook to run tests..."
        echo "npm test" >.git/hooks/pre-commit
        chmod +x .git/hooks/pre-commit

    elif [ -f "manage.py" ]; then
        echo "This is a Django project."

        echo "Creating pre-commit hook to run tests..."
        echo "python3 manage.py test" >.git/hooks/pre-commit
        chmod +x .git/hooks/pre-commit

    elif [ -f "docker-compose.yml" ]; then
        echo "This is a Docker Compose project"
        # echo "Creating pre-commit hook to run tests..."
        # echo "docker-compose up --build \n docker-compose exec" > .git/hooks/pre-commit

      
       
        # chmod +x .git/hooks/pre-commit

    elif [ -f "composer.json" ]; then
        echo "This is a PHP project."
        echo "Creating pre-commit hook to run tests..."
        echo "phpunit" >.git/hooks/pre-commit
        chmod +x .git/hooks/pre-commit

    elif jq '.dependencies | has("@angular/core")' package.json; then
        echo "This is an Angular project."
        echo "Creating pre-commit hook to run tests..."
        echo "ng test" >.git/hooks/pre-commit
        chmod +x .git/hooks/pre-commit

    else
        echo "Could not determine project type."
    fi
    # fi

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

# Will build and tag the image here.

build_image() {

    if [ -f "Dockerfile" ]; then
        echo "This is a Dockerized project, building image..."
        echo "Type Your version (MAJOR.MINOR.PATCH):"
       
        read version

        echo "Please type the image name"
        
        read imagename 

        sudo docker build -t $imagename:$version .

    elif [ ! -f "DockerFile" ]; then
        dockerize_project
        echo "This is a Dockerized project, building image..."
        echo "Type Your version (MAJOR.MINOR.PATCH):"
        read version
        read imagename 
        sudo docker build -t $imagename:$version .

        else
        echo "Cannot create Image"

    fi
}


# Will pull repo while identifying the project installing and running the project.

pull_repo() {

    echo "${green}Type Your origin Branch:"
    read branch
    git pull origin $branch
    if [ $? -ne 0 ]; then
        echo "There were merge conflicts. Please resolve them before committing."
        git status
    else
        git add .
        system_username=$(whoami)
        current_date=$(date +"%d/%m/%Y %T")
        echo Type Your Commit message:
        read varname
        remote_url=$(git remote -v | grep -m1 "^origin" | awk '{print $2}')
        project_name=$(echo $remote_url | awk -F[/:] '{print $4}')

        git commit -m "by $system_username on $current_date with message:$varname, Project:$project_name"
        check_project
    fi
}

# Will push the repo use commit formatter use pre commits and will also dockerize and build the image before deployment.

push_repo() {
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
    echo "Git push completed "
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
sudo apt-get install toilet

sudo apt-get install docker

sudo apt-get pre-commit
sudo apt install jq

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
    [17
    10H | _______I_I_I_I_I_I_I_______ |
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

[![License: GPL v3](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](http://www.gnu.org/licenses/gpl-3.0) [![Code Climate](https://img.shields.io/codeclimate/github/bicimapa/bicimapa-bot.svg)](https://codeclimate.com/github/bicimapa/bicimapa-bot)

# bicimapa-bot

Bot facebook messenger for Bicimapa 🤖

<a href="https://m.me/bicimapa"><img src="https://github.com/bicimapa/bicimapa-bot/raw/master/messenger_code.png?raw=true" alt="mesenger code" width="300px" height="300px"></a>

![Showcase gif](https://github.com/bicimapa/bicimapa-bot/blob/master/bot-showcase.gif?raw=true)

## How to run with docker 🐳
Clone the project

    git clone git@github.com:bicimapa/bicimapa-bot.git
    
Build the docker containers

    cd bicimapa-bot
    docker-compose build
       
Configure the API keys
    
    cp .env.sample .env
    vim .env      
     
Run

    docker-compose up
 
## License

[GPL v3](https://github.com/bicimapa/bicimapa-web/blob/master/LICENSE.txt)
 

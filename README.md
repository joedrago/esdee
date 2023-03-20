Directions:

* Setup Stable Diffusion Web UI
  * Install Python 3.10.6
  * Install Git
  * Clone: https://github.com/AUTOMATIC1111/stable-diffusion-webui
  * Edit webui-user.bat to have `--api` as a commandline arg
  * Run

* Create a discord app
* Create a bot for your discord app, saving the bot secret
* Using the app's Application ID `YOUR_APP_ID` (it'll be a number), create this url:
  * `https://discord.com/oauth2/authorize?client_id=YOUR_APP_ID&scope=bot&permissions=277025492032`
* Visit in a browser and add your bot to your test server

* clone repo
* copy `esdee.json.example` to `esdee.json`
* edit esdee.json to have your bot's secret
* run:

    npm install
    npm run start

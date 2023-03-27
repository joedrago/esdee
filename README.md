# Esdee: Your Favorite Stable Diffusion Bot

Esdee (pronounced "ESS dee") is a simple, configurable bot for [AUTOMATIC1111's stable diffusion UI](https://github.com/AUTOMATIC1111/stable-diffusion-webui) running on the same machine as the bot. It allows people in a Discord server to give terse commands in a channel (with some easy configuration settings or attached images), and esdee will detect them and turn them into a series of requests for the SD UI, and then funnel the resultant images back to Discord as image attachments.

# Prerequisite: SD UI in `--api` Mode

* Setup Stable Diffusion Web UI
  * Install Git and [Python 3.10.6](https://www.python.org/downloads/release/python-3106/)
    * Ensure both `git` and `python` are in your PATH
  * `git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui`
  * Edit `webui-user.bat` to have `--api` as a commandline arg
  * Run `webui-user.bat`
* Optional
  * Install some additional model checkpoints into `stable-diffusion-webui/models/stable-diffusion`

# Prerequisites: Registered Discord App/Bot

* Create a [Discord Application](https://discord.com/developers/applications)
  * Copy/save the `APPLICATION ID`
  * Go to the Bot section and create a new bot
    * Enable "Message Content Intent"
    * Click Save Changes
    * Copy/save the `TOKEN`
    * Optional: Choose a pretty icon/avatar for your bot
* Using the app's Application ID `YOUR_APP_ID` (it'll be a number), create this url:
  * `https://discord.com/oauth2/authorize?client_id=YOUR_APP_ID&scope=bot&permissions=277025492032`
* Visit in a browser and add your bot to your test server
  * Optional: Allow/Restrict which channels your bot can read on this server

# Installation

* Clone this repo
  * `git clone https://github.com/joedrago/esdee.git`
* copy `esdee.json.example` to `esdee.json`
* edit `esdee.json` to have your bot's `TOKEN`, and add any additional models you installed
* run:

        npm install
        npm run start

You should see the bot "login" with the name you gave your bot on Discord. Finally, in a channel esdee can see, type `#sd`. If the bot responds, you did it!

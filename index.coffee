#require 'newrelic'
ua = require('universal-analytics')
http = require 'http'
util = require 'util'
express = require 'express'
body_parser = require 'body-parser'
_ = require 'lodash'
Request = require 'request'
FBMessage = require './fb_message'
#hammurabi = require './hammurabi'
Parse = require 'parse/node'
giphy = require('giphy-api')()

game_status = {}
game_responses = {}
my_last_message = {}


track_strategy = (context, strategy)->
    console.log("[#{context.user.id}] - Strategy - #{strategy}")
    context.visitor.pageview("/hammurabi/#{strategy}").send()

start_game_strategy = (context)->
  if _.isEmpty(context.game_status)
    return yes

resolve = (message)->
  strategies = [
    tutorial_strategy
    start_game_strategy
    ask_for_buy_sell
    ask_for_feed
    ask_for_seed
    tick_strategy
    finish_strategy
  ]

  user = bot_message.user()
  text = bot_message.text()

  context = {
    visitor: ua(app.get('ga-id'), user.id, {strictCidFormat: false})
    user: user
    game_status: game_status[user.id]
    responses: game_responses[user.id]
    send: (message)->
      my_last_message[user.id] = message
      bot_message.send message
    text: message
  }

  _.any strategies, (strategy)-> strategy(context)

Parse.initialize process.env.PARSE_APP_ID, process.env.PARSE_REST_KEY, process.env.PARSE_MASTER_KEY
Parse.Cloud.useMasterKey()

# App create
app = express()
app.set "views", "./"
app.set "port", process.env.PORT || 5001
app.set "ga-id", process.env.GA_ID
app.set "parse-app-id", process.env.PARSE_APP_ID
app.set "fb-app-id", process.env.FB_APP_ID
app.set "fb-user-token", process.env.FB_USER_TOKEN
app.enable "trust proxy"
app.engine "html", require("ejs").renderFile
json_parser = body_parser.json()
app.use "/fonts", express.static("./fonts",
	maxAge: app.get("maxAge")
)
app.use "/images", express.static("./images",
	maxAge: app.get("maxAge")
)
app.use "/scripts", express.static("./scripts",
	maxAge: app.get("maxAge")
)
app.use "/css", express.static("./css",
	maxAge: app.get("maxAge")
)
app.use "/bower_components", express.static("./bower_components",
	maxAge: app.get("maxAge")
)

app.post '/fb/webhook', json_parser, (request,response)->
    input_message = request.body
    console.log(JSON.stringify(input_message))
    resolve new FBMessage(input_message)
    response.send({success: true})

app.get '/fb/webhook', (request,response)->
  if (request.query['hub.verify_token'] is process.env.FB_MESSENGER_VERIFY_TOKEN)
    response.send(request.query['hub.challenge'])
  else
    response.send('Error, wrong validation token')

app.get '/signup', (request, response)->
	console.log "SIGNUP #{request.param('id')}"
	Request {
		url: "https://graph.facebook.com/v2.6/#{app.get('fb-app-id')}/roles"
		method: 'POST'
		qs:
			access_token: app.get('fb-user-token')
			user: request.param('id')
			role: 'testers'
	}, (err, res, body)-> 
		console.log body
		response.redirect('http://messenger.com/t/hammurabi.bot')

app.get '*', (request, response)->
	response.render 'index.html', {
		parse: {
			appId: app.get 'parse-app-id'
		}
		fb: {
			appId: app.get 'fb-app-id'
		}
		ga:{
			id: app.get 'ga-id'
		}
	}

server = http.createServer(app)
server.listen app.get("port"), ->
	util.log "Listening on port " + app.get("port").toString() + ", running in " + app.get("env") + " environment."

module.exports = app
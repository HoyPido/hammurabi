#require 'newrelic'
ua = require('universal-analytics')
http = require 'http'
util = require 'util'
express = require 'express'
body_parser = require 'body-parser'
_ = require 'lodash'
Request = require 'request'
FBMessage = require './fb_message'
hammurabi = require './hammurabi'
Parse = require 'parse/node'
giphy = require('giphy-api')()
users = []

game_status = {}
game_responses = {}
my_last_message = {}

game_questions = {
  acres : ['How many acres do you wish to buy or sell?. enter a negative amount to sell bushels']
  feed: ['How many bushels do you wish to feed your people?. each citizen needs 20 bushels a year']
  seed: ['How many acres do you wish to plant with seed? each acre takes one bushel']
}
actions = {
  start_game : ['start', 'restart', 'cancel']
}
matches_any_word = (keywords, text)->
    words = text.split /[\n|,]/
    for key in keywords
        for word in words
            if _.contains word, key
                return true
    return false

track_strategy = (context, strategy)->
    console.log("[#{context.user.id}] - Strategy - #{strategy}")
    context.visitor.pageview("/hammurabi/#{strategy}").send()

show_tutorial = (context)->
  context.message.send ['Try your hand at governing ancient Sumeria successfully for a 10 year term of office.'
                       "Hammurabi (or, the game Hamurabi), one of the earliest computer games, is the great granddaddy of strategy and resource allocation games such as Civilization."
                       "Hammurabi is named for the second millenium B.C. Babylonian king recognized for codifying laws, known as The Code of Hammurabi."
                       "The game of Hammurabi lasts 10 years, and each year you determine how to allocate your scarce bushels of grain: buying and selling acres of land, feeding your population, and planting seeds for next year's crops"
  ].join('\n')

  context.message.send ["The Rules:"
                      "The game lasts 10 years, with a year being one turn."
                      "Each year, enter how many bushels of grain to allocate to buying (or selling) acres of land, feeding your population, and planting crops for the next year."
                      "Each person needs 20 bushels of grain each year to live and can till at most 10 acres of land."
                      "Each acre of land requires one bushel of grain to plant seeds."
                      "The price of each acre of land fluctuates from 17 bushels per acre to 26 bushels."
                      "If the conditions in your country ever become bad enough, the people will overthrow you and you won't finish your 10 year term."
                      "If you make it to the 11th year, your rule will be evaluated and you'll be ranked against great figures in history."
  ].join('\n')

  context.message.send [
    "Along the way, you'll deal with famine, plagues, fluctuating crop yields and varying prices for land."
    "The object of the game is to last 10 years to the end of your term and to leave the city better off than how you found it."
    "Leaders are evaluated based on how many people starved during one's leadership, and how much land per person remains after the end of the 10 year term."
  ].join('\n')

tutorial_strategy = (context)->
    if _.includes(users, context.user.id)
      return no
    track_strategy(context, 'tutorial')
    users.push(context.user.id)
    show_tutorial(context)
    return no

show_game_status = (context)->
	context.message.send ["The report for year: " + context.game_status.year
                      	"Starved: " + context.game_status.starved
                      	"Newcomers: " + context.game_status.newcomers
                      	"Population: " + context.game_status.population
                      	"Acres: " + context.game_status.acres
                      	"Bushels: " + context.game_status.bushels
                      	"Harvest: " + context.game_status.harvest
                      	"Rats: " + context.game_status.rats
                      	"Price: " + context.game_status.price
                      ].join('\n')

start_game_strategy = (context)->

  matches_word = matches_any_word actions.start_game, context.text
  if _.isEmpty(context.game_status) or matches_word
    track_strategy(context, 'start_game')
    context.game_status = hammurabi.create_game()
    context.game_responses = {}
    game_status[context.user.id] = context.game_status
    game_responses[context.user.id] = context.game_responses
    show_game_status(context)

  return no

log_strategy = (context)->
  console.log ["The report for year: " + context.game_status.year
  	"Starved: " + context.game_status.starved
  	"Newcomers: " + context.game_status.newcomers
  	"Population: " + context.game_status.population
  	"Acres: " + context.game_status.acres
  	"Bushels: " + context.game_status.bushels
  	"Harvest: " + context.game_status.harvest
  	"Rats: " + context.game_status.rats
  	"Price: " + context.game_status.price
    "Responses: #{JSON.stringify context.game_responses}"
    "User ID: #{context.user.id}"
  ].join('\n')
  return no
ask_for_acres = (context)->
  if _.isNumber(context.game_responses.acres)
    return no

  track_strategy(context, 'ask_for_acres')
  acres = parseInt context.text.replace(/[\+|\s|\D|\,]/g, '')
  if _.isNumber(acres) and hammurabi.is_valid_acre(context)
    context.game_responses.acres = acres

  return context.send _.sample(game_questions.acres)


ask_for_feed = (context)->
  if _.isNumber(context.game_responses.feed)
    return no

  track_strategy(context, 'ask_for_feed')
  feed = parseInt context.text.replace(/[\+|\s|\-|\D|\,]/g, '')
  if _.isNumber(feed) and hammurabi.is_valid_feed(context)
    context.game_responses.feed = feed

  return context.send _.sample(game_questions.feed)

ask_for_seed = (context)->
  if _.isNumber(context.game_responses.seed)
    return no

  track_strategy(context, 'ask_for_seed')
  seed = parseInt context.text.replace(/[\+|\s|\-|\D|\,]/g, '')
  if _.isNumber(seed) and  hammurabi.is_valid_seed(context)
    context.game_responses.seed = seed

  return context.send _.sample(game_questions.seed)


tick_strategy = (context)->
  if !hammurabi.is_valid_move(context)
    game_responses[context.user.id] = {}
    context.send('Invalid move')
    context.send('Try another move')
    return yes

  track_strategy(context, 'tick')
  hammurabi.tick(context)
  return no

show_looser = (context)->
  track_strategy(context, 'show_looser')
  context.message.send "You have starved over 45% of the population over #{context.game_status.years} years!\n You have been kicked out of office.\n Try again."
  context.message.send "Share http://hammurabi.hoypido.com with your friends and challenge them!"
  # send link to ranking
  giphy.random 'starved', (err, res)->
      context.message.post_message {
          as_user: yes
          attachments: [{
              fallback: 'Starved!'
              title: 'Starved!'
              image_url: res.data.image_url
              thumb_url: res.data.fixed_width_small_url
          }]
      }
  return yes

show_winner = (conext)->
  track_strategy(context, 'show_winner')
  context.message.send 'Winner!'

  game = context.game_status
  context.message.send ["You win."
                        "your stats are: average starved people: #{game.performance.avg_starved},"
                        "acres per person: #{game.performance.acre_person}"
                        "Share http://hammurabi.hoypido.com with your friends and challenge them!"].join('\n')
  giphy.random 'winner', (err, res)->
      context.message.post_message {
          as_user: yes
          attachments: [{
              fallback: 'Winner!'
              title: 'Winner!'
              image_url: res.data.image_url
              thumb_url: res.data.fixed_width_small_url
          }]
      }
  return yes

finish_strategy = (context)->
  track_strategy(context, 'finish')
  if !context.game_status.ended or !context.game_status.starved
    show_game_status(context)
    return no

  if context.game_status.starved
    show_looser(context)
  if context.game_status.ended
    show_winner(context)

  game_status[context.user.id] = {}
  game_responses[context.user.id] = {}
  context.message.send('to start a new game just type "start"')


resolve = (bot_message)->
  strategies = [
    tutorial_strategy
    start_game_strategy
    log_strategy
    ask_for_acres
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
    game_responses: game_responses[user.id]
    message: bot_message
    text : _(text).deburr().toLowerCase()
    send: (message)->
      my_last_message[user.id] = message
      bot_message.send message
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
		response.redirect('http://fb.me/hammurabi.bot')

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

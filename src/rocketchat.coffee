try
	  {Robot,Adapter,TextMessage, EnterMessage, User} = require 'hubot'
catch
	  prequire = require('parent-require')
	  {Robot,Adapter,TextMessage, EnterMessage, User} = prequire 'hubot'
Chatdriver = require './rocketchat_driver'

RocketChatURL = process.env.ROCKETCHAT_URL or "localhost:3000"
RocketChatUser = process.env.ROCKETCHAT_USER or "hubot"
RocketChatPassword = process.env.ROCKETCHAT_PASSWORD or "password"
RespondToDirectMessage = process.env.RESPOND_TO_DM or "false"
class RocketChatBotAdapter extends Adapter

	init: =>
		@robot.logger.info "Starting Rocketchat adapter... VIA INIT 5"
		@robot.logger.info "Once connected to rooms I will respond to the name: #{@robot.name}"
		@robot.logger.warning "No services ROCKETCHAT_URL provided to Hubot, using #{RocketChatURL}" unless process.env.ROCKETCHAT_URL
		@robot.logger.warning "No services ROCKETCHAT_ROOM provided to Hubot, using #{RocketChatRoom}" unless process.env.ROCKETCHAT_ROOM
		@robot.logger.warning "No services ROCKETCHAT_USER provided to Hubot, using #{RocketChatUser}" unless process.env.ROCKETCHAT_USER
		return @robot.logger.error "No services ROCKETCHAT_PASSWORD provided to Hubot" unless RocketChatPassword
		@robot.logger.info "Connecting To: #{RocketChatURL}"


	run: =>
		@.init()
		lastts = new Date()

		@chatdriver = new Chatdriver RocketChatURL, @robot.logger, =>
			@robot.logger.info "Successfully Connected!"
			# @robot.logger.info JSON.stringify(rooms)
			driver = @chatdriver
			robot = @robot

			driver.login(RocketChatUser, RocketChatPassword).then (userid) =>
				robot.logger.info "Successfully Logged In as " + userid

				# driver.subscribeToRooms()

				room_ids = []
				driver.getUserRooms(userid).then (rooms) ->
					for room in rooms
						room_ids.push(room._id)
						driver.joinRoom(userid, RocketChatUser, room._id).then (result) ->
							driver.prepMeteorSubscriptions({uid: userid, roomid: room._id})

					#driver.setupReactiveRoomList (id, result) =>
						#result = result.result
						#if result.length
							#room_ids.push(result[0].rid) if room_ids.indexOf(result[0].rid) is -1
							#driver.prepMeteorSubscriptions({uid: userid, roomid: result[0].rid})
						#else
							# don't have access to the rid, so ..
							# refresh (for now) -- refactor everything based on subscriptions

					driver.setupReactiveMessageList (newmsg) =>
						if (newmsg.u._id isnt userid)  || (newmsg.t is 'uj')
							if (newmsg.rid in room_ids)
								curts = new Date(newmsg.ts.$date)
								if curts > lastts
									lastts = curts
									if newmsg.t isnt 'uj'
										user = robot.brain.userForId newmsg.u._id, name: newmsg.u.username, room: newmsg.rid
										text = new TextMessage(user, newmsg.msg, newmsg._id)
										robot.receive text
										robot.logger.info "Message sent to hubot brain."
									else   # enter room message
										if newmsg.u._id isnt userid
											user = robot.brain.userForId newmsg.u._id, name: newmsg.u.username, room: newmsg.rid
											robot.receive new EnterMessage user, null, newmsg._id

				@emit 'connected'

	send: (envelope, strings...) =>
			@chatdriver.sendMessage(str, envelope.room) for str in strings

	reply: (envelope, strings...) =>
			@robot.logger.info "reply"
			strings = strings.map (s) -> "@#{envelope.user.name} #{s}"
			@send envelope, strings...

	callMethod: (method, args...) =>
		@chatdriver.callMethod(method, args)

exports.use = (robot) ->
	new RocketChatBotAdapter robot

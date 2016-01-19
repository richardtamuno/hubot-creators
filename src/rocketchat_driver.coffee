Asteroid = require 'asteroid'

# TODO:   need to grab these values from process.env[]

_msgsubtopic = 'stream-messages' # 'messages'
_msgsublimit = 10   # this is not actually used right now
_messageCollection = 'stream-messages'

# driver specific to Rocketchat hubot integration
# plugs into generic rocketchatbotadapter

class RocketChatDriver
	constructor: (url, @logger, cb) ->
		@asteroid = new Asteroid(url)

		@asteroid.on 'connected', ->
			cb()

	getRoomId: (roomid) =>
		@logger.info "Joining Room: #{roomid}"

		r = @asteroid.call 'getRoomIdByNameOrId', roomid

		return r.result

	getUserRooms: (userId) =>
		r = @asteroid.call 'getAllUserRooms', userId
		return r.result

	joinRoom: (userid, uname, roomid, cb) =>
		console.log "JOINING ROOM " + roomid
		r = @asteroid.call 'joinRoom', roomid

		return r.result

	sendMessage: (text, roomid) =>
		@logger.info "Sending Message To Room: #{roomid}"

		@asteroid.call('sendMessage', {msg: text, rid: roomid})

	login: (username, password) =>
		@logger.info "Logging In"
		# promise returned
		return @asteroid.loginWithPassword username, password

	prepMeteorSubscriptions: (data) =>
		msgsub = @asteroid.subscribe _msgsubtopic, data.roomid, _msgsublimit
		@logger.info "Subscribing to Room: #{data.roomid}"

		return msgsub.ready

	subscribeToRooms: (data) =>
		@roomsSubscription = @asteroid.subscribe "subscription"

	setupReactiveMessageList: (receiveMessageCallback) =>
		@logger.info "Setting up reactive message list..."
		@messages = @asteroid.getCollection _messageCollection

		rQ = @messages.reactiveQuery {}
		rQ.on "change", (id) =>
			@logger.info "Change received on MESSAGE ID " + id
			changedMsgQuery = @messages.reactiveQuery {"_id": id}
			if changedMsgQuery.result && changedMsgQuery.result.length > 0
				changedMsg = changedMsgQuery.result[0]
				if changedMsg.args?
					receiveMessageCallback changedMsg.args[1]

	setupReactiveRoomList: (roomCallback) =>
		@logger.info "Setting up reactive ROOM list..."
		@rooms = @asteroid.getCollection "rocketchat_subscription"

		reactiveQuery = @rooms.reactiveQuery {}
		reactiveQuery.on "change", (id) =>
			@logger.info "Change received on SUBSCRIPTION ID " + id
			roomCallback id, @rooms.reactiveQuery {"_id": id}

	callMethod: (name, args = []) =>
		@logger.info "Calling: #{name}, #{args.join(', ')}"
		r = @asteroid.apply name, args
		return r.result

module.exports = RocketChatDriver
require 'rubygems'
require 'digest/md5'
require 'bunny'
require 'json'
require 'pg'
require 'facter'
require 'open-uri'

#parse parameters 
object_tracking_api  = ARGV[0] # object tracking api host
fqueue  = ARGV[1] # rabbitmq queue

#make sure all directories are created
FileUtils.mkdir_p "objectimages"
FileUtils.mkdir_p "sceneimages"
FileUtils.mkdir_p "log"

#initialize queue, log and api objects
lgflnm  = "log/#{fqueue}.log"
errmsg  = ''
puts "#{Time.now}: Starting..."
object_tracking_api = ObjectTrackingApiWrapper.new(object_tracking_api)

#connect to message queue
puts "#{Time.now}: Connecting to queue #{fqueue}..."
conn = Bunny.new(:host=>ENV['MESSAGEQUEUESERVER'],:port=>ENV['MESSAGEQUEUEPORT'],:user=>ENV['MESSAGEQUEUEUSER'],:password=>ENV['MESSAGEQUEUEPASS'])
conn.start
ch = conn.create_channel
ex = ch.default_exchange
ch.prefetch(Facter.value('processors')['count'])
q  = ch.queue(fqueue, :exclusive => false, :auto_delete => false, :durable => true)

q.subscribe(:block => true,:manual_ack => true) do |delivery_info, properties, body|
	object_image = JSON.parse(body)["object_image"]
	scene_image = JSON.parse(body)["scene_image"]
	if object_image and scene_image
		object_match = object_tracking_api.objectmatch(object_image,scene_image) rescue nil
		if object_match
			if object_match < 0 #-1: Object Tracking api call failure | 0: Scene file not valid, do not requeue
				ex.publish(body,:routing_key => "#{fqueue}")
				ch.ack(delivery_info.delivery_tag)
				next
			end
			result = "#{Time.now} - Score for #{object_image} is #{object_match}%"
			open(lgflnm, 'a') { |f| f.puts result }	
			begin					
				if object_match > 2 #threshold
					# insert result in database
				end
			rescue Exception => e
				open(lgflnm, 'a') { |f| f.puts "#{Time.now}: #{appurl} caught exception #{e}...requeuing" }	
				ex.publish(body,:routing_key => "#{fqueue}")		
				ch.ack(delivery_info.delivery_tag)
				next
			end
		end
	end
ch.ack(delivery_info.delivery_tag)
connct.close
require 'fileutils'
require 'fastimage'
require 'rest-client'
 
class ObjectTrackingApiWrapper
	attr_accessor :root

  def initialize(root='object_tracking_api_server')
		@root   = "http://#{root}/v1"
		@apikey = get_api_key
  end

  def objectmatch(object_image,scene_image) 
	matchres = 0
	applpt = "objectimages"
	sshtpt = "sceneimages"
	FileUtils.mkdir_p applpt
	FileUtils.mkdir_p sshtpt
	if object_image
		fphght = (600-FastImage.size(scene_image)[1])*-1 rescue nil	
		if fphght
			system("mogrify -crop +0-#{fphght} +repage #{scene_image}")
			matchres = objectmatchreq("#{@root}/objectmatch", object_image, scene_image)
			if matchres
				open("log/objectmatch.log", 'a') { |f| f.puts "#{Time.now}: #{url} - #{matchres}" }				
			end
		else
			matchres = 0 #Track API call failure
			open("log/objectmatch.log", 'a') { |f| f.puts "#{Time.now}: #{url} - #{matchres}" }	
		end
	end
	matchres
  end
	
  private  
	def objectmatchreq(object_image, scene_image)
		result = RestClient.post {api_key: @apikey, :objectfile => File.new(object_image, 'rb'), :scenefile => File.new(scene_image, 'rb')}
		puts "\nOBJECT TRACKING API Response: #{result.body}"			
		mtchrs = JSON.parse result.body	
		mtchrs['response']['match'] #rescue 0
	end
	
	def get_api_key
		# authentication key store 
	end		
end

require_relative 'oktennyx'

class Collection
	attr_accessor :client, :response
	def initialize(client, response)
		@client = client
		@response = response
		@pagination_links = []
		set_pagination
	end

	def each(&block)
		@response[0].each(&block)
	end

	def set_pagination
		# Checks for non-nil value in 1st indice. If pagination exists, this value will exist
		if self.response[1]
			@pagination_links = self.response[1].split(',')
		end
	end

	def pages_remain
		pages_remaining = nil

		for link in @pagination_links
			#latter conditional is in here for now because logs pagination is entering infinite loop and currently unsure why
			if (link.include? 'rel="next') and (self.response[0] != [])
				pages_remaining = true
			end	
		end

		return pages_remaining
	end

	def parse_pagination_link(links)
		url = nil

		for link in links
			if link.include? 'rel="next'
				url = (link.split(';')[0]).gsub(/[< >]/, '')
			end	
		end
		return url
	end

	def next
		url = parse_pagination_link(@pagination_links)
		self.response = self.client.http_req(URI(url), 'GET', {})
		self.set_pagination
		return self.response
	end
end


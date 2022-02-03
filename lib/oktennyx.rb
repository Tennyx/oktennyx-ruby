require 'uri'
require 'net/http'
require 'json'
require 'base64'
require 'OpenSSL'
require_relative 'collection'


class OktaClient
	attr_accessor :org_url, :token, :client_id, :scopes, :private_key, :access_token, :pagination
	def initialize(hash)
		self.org_url = hash[:org_url]
		self.token = hash[:token]
		self.client_id = hash[:client_id]
		self.scopes = hash[:scopes]
		self.private_key = hash[:private_key]
		self.access_token = nil
		check_authz_type
	end

	def http_req(url, http_method, body)
		https = Net::HTTP.new(url.host, url.port);
		https.use_ssl = true

		if http_method == 'GET'
			request = Net::HTTP::Get.new(url)
		elsif http_method == 'PUT'
			request = Net::HTTP::Put.new(url)
		elsif http_method == 'POST'
			request = Net::HTTP::Post.new(url)
		elsif http_method == 'DELETE'
			request = Net::HTTP::Delete.new(url)
		else
			return 405
		end

		request['Accept'] = 'application/json'
		request['Content-Type'] = 'application/json'

		if self.access_token
			request['Authorization'] = "Bearer #{self.access_token}"
		else
			request['Authorization'] = "SSWS #{self.token}"
		end

		if not body.empty?
			request.body = body
		end	

		response = https.request(request)

		if response.code == '204'
			return response.code
		else
			return JSON.parse(response.read_body), response['Link']
		end
	end

	def to_hex(int)
		int < 16 ? '0' + int.to_s(16) : int.to_s(16)
	end

	def base64_to_long(data)
		decoded_with_padding = Base64.urlsafe_decode64(data) + Base64.decode64('==')
		decoded_with_padding.to_s.unpack('C*').map do |byte|
			self.to_hex(byte)
		end.join.to_i(16)
	end

	def get_access_token(private_key, client_id, scopes)
		scopes_string = ''
		scopes.each {|scope| scopes_string += "#{scope} "}

		jwks = private_key

		jwtheader = {
			'alg': 'RS256'
		}

		jwtpayload = {
			aud: "#{self.org_url}/oauth2/v1/token",
			exp: (Time.now + 1*60*60).utc.strftime('%s'),
			iss: client_id,
			sub: client_id
		}

		jwtheaderJSON = jwtheader.to_json
		jwtheaderUTF = jwtheaderJSON.encode('UTF-8')
		tokenheader = Base64.urlsafe_encode64(jwtheaderUTF)


		jwtpayloadJSON = jwtpayload.to_json
		jwtpayloadUTF = jwtpayloadJSON.encode('UTF-8')
		tokenpayload = Base64.urlsafe_encode64(jwtpayloadUTF)


		signeddata = tokenheader + "." + tokenpayload
		
		signature = ''

		if private_key.class == Hash
			key = OpenSSL::PKey::RSA.new 2048
			exponent = private_key[:keys][0][:e]
			modulus = private_key[:keys][0][:n]
			key.set_key(self.base64_to_long(modulus), self.base64_to_long(exponent), self.base64_to_long(jwks[:keys][0][:d]))
			signature = Base64.urlsafe_encode64(key.sign(OpenSSL::Digest::SHA256.new, signeddata))
		elsif private_key.class == String
			priv = private_key
			key = OpenSSL::PKey::RSA.new(priv)
			signature = Base64.urlsafe_encode64(key.sign(OpenSSL::Digest::SHA256.new, signeddata))
		end
		
		client_secret_jwt = signeddata + '.' + signature

		url = URI("#{self.org_url}/oauth2/v1/token")
		https = Net::HTTP.new(url.host, url.port);
		https.use_ssl = true
		request = Net::HTTP::Post.new(url)
		request['Accept'] = 'application/json'
		request['Content-Type'] = 'application/x-www-form-urlencoded'
		request.body = "grant_type=client_credentials&scope=#{scopes_string}&client_assertion_type=urn%3Aietf%3Aparams%3Aoauth%3Aclient-assertion-type%3Ajwt-bearer&client_assertion=#{client_secret_jwt}"
		response = https.request(request)
		self.access_token = JSON.parse(response.read_body)['access_token']
	end

	def check_authz_type
		if self.private_key
			self.get_access_token(self.private_key, self.client_id, self.scopes)
		end
	end

	def handle_params(params)
		query_params = ''

		if not params.empty?
			query_params += '?'
			for param_key, param_value in params
				query_params += "#{param_key}=#{param_value}&"
			end
		end

		return query_params
	end	

	#---user methods

	def get_users(**params)
		query_params = self.handle_params(params)
		url = URI("#{self.org_url}/api/v1/users/#{query_params}")
		users_collection = Collection.new(self, self.http_req(url, 'GET', {}))
		return users_collection
	end

	def get_user(user_id)
		url = URI("#{self.org_url}/api/v1/users/#{user_id}")
		self.http_req(url, 'GET', {})[0]
	end

	def create_user(profile)
		url = URI("#{self.org_url}/api/v1/users")
		self.http_req(url, 'POST', profile.to_json)
	end

	def update_user(user_id, profile)
		url = URI("#{self.org_url}/api/v1/users/#{user_id}")
		new_profile = {profile: profile}
		self.http_req(url, 'PUT', new_profile.to_json)
	end

	def deactivate_user(user_id)
		url = URI("#{self.org_url}/api/v1/users/#{user_id}/lifecycle/deactivate")
		self.http_req(url, 'POST', {})
	end

	def delete_user(user_id)
		url = URI("#{self.org_url}/api/v1/users/#{user_id}")
		self.http_req(url, 'DELETE', {})
	end

	def get_user_groups(user_id)
		url = URI("#{self.org_url}/api/v1/users/#{user_id}/groups")
		self.http_req(url, 'GET', {})
	end

	def get_user_factors(user_id)
		url = URI("#{self.org_url}/api/v1/users/#{user_id}/factors")
		self.http_req(url, 'GET', {})
	end

	def enroll_factor(user_id, factor_profile)
		url = URI("#{self.org_url}/api/v1/users/#{user_id}/factors")
		self.http_req(url, 'POST', factor_profile.to_json)
	end

	def activate_factor(user_id, factor_id, activation_profile)
		url = URI("#{self.org_url}/api/v1/users/#{user_id}/factors/#{factor_id}/lifecycle/activate")
		self.http_req(url, 'POST', activation_profile.to_json)
	end

	def verify_factor(user_id, factor_id, verify_profile)
		url = URI("#{self.org_url}/api/v1/users/#{user_id}/factors/#{factor_id}/verify")
		self.http_req(url, 'POST', verify_profile.to_json)
	end

	#---group methods

	def get_groups(**params)
		query_params = self.handle_params(params)
		url = URI("#{self.org_url}/api/v1/groups/#{query_params}")
		groups_collection = Collection.new(self, self.http_req(url, 'GET', {}))
		return groups_collection
	end

	def get_group(group_id)
		url = URI("#{self.org_url}/api/v1/groups/#{group_id}")
		self.http_req(url, 'GET', {})
	end

	def create_group(profile)
		url = URI("#{self.org_url}/api/v1/groups")
		self.http_req(url, 'POST', profile.to_json)
	end

	def add_user_to_group(user_id, group_id)
		url = URI("#{self.org_url}/api/v1/groups/#{group_id}/users/#{user_id}")
		self.http_req(url, 'PUT', {})
	end

	def remove_user_from_group(user_id, group_id)
		url = URI("#{self.org_url}/api/v1/groups/#{group_id}/users/#{user_id}")
		self.http_req(url, 'DELETE', {})
	end

	#---app methods

	def get_applications(**params)
		query_params = self.handle_params(params)
		url = URI("#{self.org_url}/api/v1/apps/#{query_params}")
		apps_collection = Collection.new(self, self.http_req(url, 'GET', {}))
		return apps_collection		
	end

	def get_application(app_id)
		url = URI("#{self.org_url}/api/v1/apps/#{app_id}")
		self.http_req(url, 'GET', {})
	end

	def create_application(app_profile)
		url = URI("#{self.org_url}/api/v1/apps")
		self.http_req(url, 'POST', app_profile.to_json)
	end

	def assign_user_to_app(user_id, user_profile, app_id)
		url = URI("#{self.org_url}/api/v1/apps/#{app_id}/users")
		user = {
			id: user_id,
		}
		self.http_req(url, 'POST', user.to_json)
	end

	#---logs methods

	def get_logs(**params)
		query_params = self.handle_params(params)
		url = URI("#{self.org_url}/api/v1/logs/#{query_params}")
		logs_collection = Collection.new(self, self.http_req(url, 'GET', {}))
		return logs_collection	
	end
end
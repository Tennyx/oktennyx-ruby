# Oktennyx (Ruby Gem)

Unofficial Ruby Management SDK to interact with Okta orgs.

## Installation

- In the command line, run: `gem install oktennyx` and make sure to import the gem in your code via `require 'oktennyx'`

https://rubygems.org/gems/oktennyx

## Authorization

Instantiate a client object with either an Okta API token or a private key in either JWK or PEM format. Examples of both:

## API Token

```ruby
client = OktaClient.new({
	org_url: 'https://{okta_domain}',
	token: '{api_token}'
})
```

## OAuth Access Token

Instantiate either with JWK format:
```ruby
client = OktaClient.new({
	org_url: 'https://{okta_domain}',
	client_id: '{client_id}',
	scopes: ['okta.users.read', 'okta.users.manage'],
	private_key: {
		"keys": [
			{
				"p": "26Cj_lCsek-Rid...",
				"kty": "RSA",
				"q": "0dgtcdwWmiut8N...",
				"d": "QIKprdpHbCw9UM...",
				"e": "AQAB",
				"qi": "YhGayFLsgu2h6...",
				"dp": "I5D3HbcIx2HdS...",
				"dq": "uw8_K5FrIJGxY...",
				"n": "tAecae-adLXoid..."
			}
		]
	}
})
```

Or PEM format:

```ruby
client = OktaClient.new({
	org_url: 'https://{okta_domain}',
	client_id: '{client_id}',
	scopes: ['okta.users.read', 'okta.users.manage'],
	private_key: '-----BEGIN RSA PRIVATE KEY-----
                MIIEowIBAAKCAQEAtAe...
                -----END RSA PRIVATE KEY-----'
})
```

## Usage guide

### Get All Users

```ruby
users = client.get_users()
```

Additionally, you can pass [request parameters](https://developer.okta.com/docs/reference/api/users/#request-parameters-3) as an object to the method in order to utilize functionality like filtering. Example:

```ruby
users = client.get_users({filter: 'profile.firstName' eq "Case"'})
```

### Get User

```ruby
user = client.get_user(user_id)
```

### Create User

```ruby
new_user = {
	profile: {
		firstName: 'Molly',
		lastName: 'Millions',
		email: 'molly.millions@example.com',
		login: 'molly.millions@example.com'
	},
	credentials: {
		password: {
			value: 'Cyb3r$p4c3'
		}
	}
}
user = client.create_user(new_user)
```
### Update User

```ruby
user = client.get_user(user_id)
new_profile = user['profile']
new_profile['mobilePhone'] = 8021234567
updated_user = client.update_user('00u1oo1oh0E7dwQUT4x7', new_profile)
```

### Deactivate User

```ruby
client.deactivate_user(user_id)
```

### Delete User

```ruby
client.delete_user(user_id)
```

### Get User's Groups

```ruby
users_groups = client.get_user_groups(user_id)
```

### Add User to Group

```ruby
client.add_user_to_group(user_id, group_id)
```

### Remove User from Group

```ruby
client.remove_user_from_group(user_id, group_id)
```

### Enroll Factor for User

```ruby
client.enroll_factor(user_id, factor_profile)
```
The **factor_profile** should be an object reflecting the object passed to the API for the relevant factor. For example, factor_profile for an SMS factor would look like this:

```ruby
{
	factorType: 'sms',
	provider: 'OKTA',
		profile: {
			phoneNumber: '7168641100'
		}
}
```

As referenced [here](https://developer.okta.com/docs/reference/api/factors/#enroll-okta-sms-factor).

### Get User's Factors

```ruby
user_factors = client.get_user_factors(user_id)
```

### Activate User Factor

```ruby
client.activate_factor(user_id, factor_id, activation_profile)
```

The **activation_profile** should be an object with relevant values for the factor. For instance, for an SMS factor the object would be `{ passCode: '791602' }`. Example request for this factor in the api [here](https://developer.okta.com/docs/reference/api/factors/#request-example-27).

### Get All Groups

```ruby
groups = client.get_groups()
```

Additionally, you can pass [request parameters](https://developer.okta.com/docs/reference/api/groups/#request-parameters-3) as an object to the method in order to utilize functionality like filtering. Example:

```ruby
groups = client.get_groups({search: 'type eq "APP_GROUP"'})
```

### Get Group

```ruby
group = client.get_group(group_id)
```

### Create Group

```ruby
new_group = {
	profile: {
		name: 'Ono-Sendai',
		description: 'Cyberdeck Manufacturer'
	}
}
group = client.create_group(new_group)
```

### Get All Applications

```ruby
apps = client.get_applications()
```

Additionally, you can pass [request parameters](https://developer.okta.com/docs/reference/api/apps/#request-parameters-3) as an object to the method in order to utilize functionality like filtering. Example:

```ruby
apps = client.get_applications({q: 'Straylight'})
```

### Get Application

```ruby
app = client.get_application(app_id)
```

### Create Application

```ruby
# Profile example for basic auth application

app_profile = {
	name: 'template_basic_auth',
	label: 'Straylight',
	signOnMode: 'BASIC_AUTH',
	settings: {
		app: {
			url: 'https://example.com/auth.htm',
			authURL: 'https://example.com/login.html'
		}
	}	
}
new_app = client.create_application(app_profile)
```

```ruby
# Profile example for SWA application

app_profile = {
	name: 'template_swa',
	label: 'SWA Test App',
	signOnMode: 'BROWSER_PLUGIN',
	settings: {
		app: {
			buttonField: 'btn-login',
			passwordField: 'text-box-password',
			usernameField: 'txt-box-username',
			url: 'https://example.com/login.html',
			loginUrlRegex: '^https://example.com/login.html$'
		}
	}
}
new_app = client.create_application(app_profile)
```

### Assign User to Application

```ruby
user = client.get_user(user_id)
client.assign_user_to_app(user['id'], user['profile'], app_id)
```

### Get Logs

```ruby
logs = client.get_logs()
```

Additionally, you can pass [request parameters](https://developer.okta.com/docs/reference/api/system-log/#request-parameters) as an object to the method in order to utilize functionality like filtering. Example:

```ruby
logs = client.get_logs(**{since: '2021-06-10T14:00:00Z'})
```

### Pagination

Any collection objects returned can utilize pagination if a limit is passed as an argument. Some examples of using pagination:

```ruby
users = client.get_users(**{limit: 10})

while users.pages_remain
	puts users.next
end


groups = client.get_groups(**{limit: 10})

while groups.pages_remain
	puts groups.next
end

apps = client.get_applications(**{limit: 10})

while apps.pages_remain
	puts apps.next
end

logs = client.get_logs(**{limit: 10, since: '2021-07-26T12:00:00Z'})

while logs.pages_remain
	puts logs.next
end
```


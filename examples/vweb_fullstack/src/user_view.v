module main

import vweb

['/users'; get]
pub fn (mut app App) users() !vweb.Result {
	token := app.get_cookie('token') or {
		app.set_status(400, '')
		return app.text('${err}')
	}
	users := get_users(token) or {
		app.set_status(400, '')
		return app.text('Failed to fetch data from the server. Error: ${err}')
	}
	println(users)

	return $vweb.html()
}

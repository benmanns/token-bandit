require 'json'

require 'bundler'
Bundler.require

STDOUT.sync = true

class App < Sinatra::Base
  use Rack::Session::Cookie, secret: ENV['SSO_SALT']

  helpers do
    def protected!
      unless authorized?
        response['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
        throw(:halt, [401, "Not authorized\n"])
      end
    end

    def authorized?
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? && @auth.basic? && @auth.credentials && 
      @auth.credentials == [ENV['HEROKU_USERNAME'], ENV['HEROKU_PASSWORD']]
    end
  end

  get '/' do
    halt 403, 'not logged in' unless session[:heroku_sso]
    haml :index
  end

  def sso
    halt 403 if params[:timestamp].to_i < (Time.now - 2 * 60).to_i

    token = Digest::SHA1.hexdigest("#{params[:id]}:#{ENV['SSO_SALT']}:#{params[:timestamp]}")
    halt 403 unless token == params[:token]

    session[:authenticity_token] = params[:authenticity_token]
    session[:app] = params[:app]

    redirect '/'
  end

  get('/heroku/resources/:id') { sso }
  post('/sso/login') { sso }

  post '/heroku/resources' do
    protected!

    status 201
    JSON.dump(id: 0)
  end

  delete '/heroku/resources/:id' do
    protected!

    'ok'
  end

  put '/heroku/resources/:id' do
    protected!

    '{}'
  end
end

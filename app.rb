require 'sinatra'

set :revision, `git rev-parse --short HEAD`
set :headlines, ["Spinning Newspaper Injures Printer"]

get '/' do
  headline = params[:q] || settings.headlines.sample
  erb :paper, locals: { headline: headline, revision: settings.revision }
end

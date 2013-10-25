require 'sinatra'
require 'csv'
require 'digest/md5'
require 'literate_randomizer'

set :revision, `git rev-parse --short HEAD`
set :cache, {}
set :headlines, CSV.read(File.join(settings.root, "headlines.csv"), headers: true)["Text"].concat([
    "Spinning Newspaper Injures Printer",
    "Squirrel Resembling Abraham Lincoln Found",
    "Cosmetics Scare In Gotham"
  ])

get '/' do
  headline = (params[:q] || settings.headlines.sample).strip
  checksum = Digest::MD5.hexdigest(headline)
  settings.cache.fetch(checksum) do |sum|
    view = erb :paper, locals: {
      headline: headline,
      checksum: sum,
      revision: settings.revision,
      paragraphs: LiterateRandomizer.paragraphs(join: false, paragraphs: 12..18)
    }
    settings.cache[sum] = view if params[:q]
    view
  end
end


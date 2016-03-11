json.array!(@posts) do |post|
  json.extract! post, :id, :title, :context
  json.url post_url(post, format: :json)
end

# locals: suggestion, current_user_vote (optional)

json.extract! suggestion,
              :id,
              :title,
              :description,
              :description_plain,
              :status,
              :tags,
              :upvotes_count,
              :downvotes_count,
              :created_at,
              :updated_at

json.images do
  json.array! suggestion.images.attachments do |attachment|
    json.id attachment.id
    json.url Rails.application.routes.url_helpers.url_for(attachment, only_path: true)
  end
end

json.user do
  json.id suggestion.user.id
  json.name suggestion.user.name
  json.avatar_url suggestion.user.avatar_url
end

json.current_user_vote local_assigns[:current_user_vote] if local_assigns.key?(:current_user_vote)
